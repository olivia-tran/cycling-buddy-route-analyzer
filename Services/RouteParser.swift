import Foundation
import Combine
import FirebaseAnalytics

@MainActor
class RouteParser: ObservableObject {

    @Published var segments: [RouteSegment] = []
    @Published var routeName: String = ""
    @Published var totalMiles: Double = 0
    @Published var totalElevFt: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routeURLString: String = ""

    // MARK: – Derived stats

    var climbs: [RouteSegment] {
        segments.filter { $0.isClimb }
            .sorted { $0.elevDiffFt > $1.elevDiffFt }
    }

    var steepestDescent: RouteSegment? {
        segments.filter { $0.isDescent }
            .min { $0.avgGradePercent < $1.avgGradePercent }
    }

    // MARK: – Entry point

    func analyze(urlString: String) async {
        isLoading = true
        errorMessage = nil
        segments = []
        routeURLString = urlString
        totalMiles = 0
        totalElevFt = 0
        routeName = ""

        defer { isLoading = false }

        guard let routeID = extractRouteID(from: urlString) else {
            errorMessage = "Invalid Strava route URL."
            Analytics.logEvent("parse_failure", parameters: [
                "reason": "invalid_url" as NSObject
            ])
            return
        }

        guard let token = UserDefaults.standard.string(forKey: "strava_access_token") else {
            errorMessage = "Strava not connected."
            Analytics.logEvent("parse_failure", parameters: [
                "reason": "missing_token" as NSObject
            ])
            return
        }

        do {
            try await fetchRoute(routeID: routeID, token: token)
        } catch {
            errorMessage = error.localizedDescription
            Analytics.logEvent("parse_failure", parameters: [
                "reason": "api_error" as NSObject
            ])
        }
    }

    // MARK: – Extract Route ID

    private func extractRouteID(from urlString: String) -> String? {

        guard let url = URL(string: urlString) else { return nil }

        let parts = url.pathComponents

        guard let routesIndex = parts.firstIndex(of: "routes"),
              routesIndex + 1 < parts.count else {
            return nil
        }

        let id = parts[routesIndex + 1]

        return id.allSatisfy(\.isNumber) ? id : nil
    }

    // MARK: – API Fetch

    private func fetchRoute(routeID: String, token: String) async throws {

        guard let url = URL(string:
            "https://www.strava.com/api/v3/routes/\(routeID)"
        ) else {
            throw RouteParserError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw RouteParserError.invalidResponse
        }

#if DEBUG
        if let text = String(data: data, encoding: .utf8) {
            print("[RouteParser] API status:", http.statusCode)
            print("[RouteParser] API body prefix:\n", text.prefix(600))
        }
#endif

        switch http.statusCode {

        case 200:
            let decoded = try JSONDecoder().decode(StravaRouteResponse.self, from: data)
            applyRoute(decoded)

        case 401:
            throw RouteParserError.unauthorized

        case 404:
            throw RouteParserError.notFound

        default:
            throw RouteParserError.httpError(http.statusCode)
        }
    }

    // MARK: – Apply Data

    private func applyRoute(_ route: StravaRouteResponse) {

        routeName = route.name

        totalMiles = (route.distance ?? 0) / 1609.344

        totalElevFt = Int(((route.elevation_gain ?? 0) * 3.28084).rounded())

        segments = (route.segments ?? []).map { seg in

            let elevMeters = (seg.elevation_high ?? 0) - (seg.elevation_low ?? 0)

            return RouteSegment(
                name: seg.name,
                distanceMiles: (seg.distance ?? 0) / 1609.344,
                elevDiffFt: Int((elevMeters * 3.28084).rounded()),
                avgGradePercent: seg.average_grade ?? 0
            )
        }
    }
}
