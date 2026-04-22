import Foundation

enum RouteParserError: LocalizedError {

    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case httpError(Int)

    var errorDescription: String? {

        switch self {

        case .invalidURL:
            return "Invalid Strava API URL."

        case .invalidResponse:
            return "Invalid response from Strava."

        case .unauthorized:
            return "Strava authorization expired. Reconnect your account."

        case .notFound:
            return "Route not found."

        case .httpError(let code):
            return "Strava API error \(code)."
        }
    }
}
