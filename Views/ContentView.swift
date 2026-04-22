import SwiftUI
import FirebaseAnalytics
import AuthenticationServices
import UIKit

struct ContentView: View {
    @StateObject private var parser = RouteParser()
    @StateObject private var parserB = RouteParser()
    @StateObject private var stravaAuth = StravaAuthManager()

    @State private var urlInput: String = ""
    @State private var urlInput2: String = ""
    @State private var navigateToResults = false
    @State private var navigateToComparison = false
    @State private var isStravaConnected = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cbBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 4) {
                        Text("CYCLING BUDDY")
                            .font(.custom("BebasNeue-Regular", size: 42))
                            .tracking(6)
                            .foregroundColor(.cbText)

                        Text("KNOW BEFORE YOU GO")
                            .font(.custom("DMMono-Regular", size: 10))
                            .tracking(3)
                            .foregroundColor(.cbAccent)
                    }
                    .padding(.bottom, 32)

                    ElevationHeroShape()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: isStravaConnected ? "checkmark.seal.fill" : "person.crop.circle.badge.exclam")
                                .foregroundColor(isStravaConnected ? .green : .cbAccent)

                            Text(isStravaConnected ? "Connected to Strava" : "Not connected to Strava")
                                .font(.custom("DMMono-Regular", size: 11))
                                .foregroundColor(.cbText)
                        }

                        Button {
                            print("[OAuth] Connect tapped")
                            stravaAuth.startOAuth()
                        } label: {
                            Text(isStravaConnected ? "Reconnect Strava" : "Connect Strava")
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.cbAccent)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel("Connect to Strava")
                        .accessibilityHint("Opens Strava to authorize read access")
                    }
                    .padding(14)
                    .background(Color.cbCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cbBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("STRAVA ROUTE URL")
                            .font(.custom("DMMono-Regular", size: 9))
                            .tracking(2)
                            .foregroundColor(.cbMuted)

                        TextField("https://www.strava.com/routes/...", text: $urlInput)
                            .font(.custom("DMMono-Regular", size: 13))
                            .foregroundColor(.cbAccent)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding(.vertical, 4)
                    }
                    .padding(18)
                    .background(Color.cbCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cbBorder, lineWidth: 1.5)
                    )
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("OPTIONAL: SECOND STRAVA ROUTE URL (ADD TO COMPARE)")
                            .font(.custom("DMMono-Regular", size: 9))
                            .tracking(2)
                            .foregroundColor(.cbMuted)

                        TextField("https://www.strava.com/routes/...", text: $urlInput2)
                            .font(.custom("DMMono-Regular", size: 13))
                            .foregroundColor(.cbAccent)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding(.vertical, 4)
                    }
                    .padding(18)
                    .background(Color.cbCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cbBorder, lineWidth: 1.5)
                    )
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    Button {
                        Task {
                            Analytics.logEvent("analyze_routes_tap", parameters: [
                                "second_url_present": (urlInput2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "false" : "true") as NSObject
                            ])

                            if urlInput2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                await parser.analyze(urlString: urlInput)

                                if hasUsableRouteData(parser) {
                                    navigateToResults = true
                                }
                            } else {
                                async let first: Void = parser.analyze(urlString: urlInput)
                                async let second: Void = parserB.analyze(urlString: urlInput2)
                                _ = await (first, second)

                                navigateToComparison = hasUsableRouteData(parser) && hasUsableRouteData(parserB)
                            }
                        }
                    } label: {
                        Group {
                            if parser.isLoading || parserB.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("ANALYZE ROUTE(S)")
                                    .font(.custom("BebasNeue-Regular", size: 20))
                                    .tracking(3)
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.cbAccent)
                        .cornerRadius(14)
                        .accessibilityLabel("Analyze routes")
                        .accessibilityHint("Analyzes one or two pasted Strava route links")
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parser.isLoading || parserB.isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                    if let err = parser.errorMessage {
                        Text(err)
                            .font(.custom("DMMono-Regular", size: 10))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.cbMuted)
                            .font(.system(size: 12, weight: .regular))
                            .padding(.top, 2)

                        Text("Not affiliated with Strava. Data from public sources; verify conditions. Ride safely and have fun.")
                            .font(.custom("DMMono-Regular", size: 9))
                            .foregroundColor(.cbMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cbCard.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cbBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    Link(destination: URL(string: "https://instagram.com/aerial.olivia")!) {
                        HStack {
                            Image(systemName: "paperplane")
                                .foregroundColor(.cbAccent)

                            Text("Feature requests / bug reports: Instagram @aerial.olivia")
                                .font(.custom("DMMono-Regular", size: 9))
                                .foregroundColor(.cbText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.cbCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cbBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .accessibilityLabel("Open Instagram profile aerial dot olivia for feature requests and bug reports")
                        .accessibilityHint("Opens Instagram in your browser or app")
                    }

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $navigateToResults) {
                RouteOverviewView(parser: parser)
            }
            .navigationDestination(isPresented: $navigateToComparison) {
                RouteComparisonView(parserA: parser, parserB: parserB)
            }
            .alert("Couldn't Load Route", isPresented: .constant(parser.errorMessage != nil)) {
                Button("OK") {
                    parser.errorMessage = nil
                }
            } message: {
                Text(parser.errorMessage ?? "")
            }
        }
        .onOpenURL { url in
            // Handle custom scheme callbacks from Strava OAuth
            guard url.scheme == "cyclingbuddy" else { return }

            // Accept both formats:
            // cyclingbuddy://oauth-callback?code=...
            // cyclingbuddy://localhost/oauth-callback?code=...
            let isOAuthCallback: Bool = {
                if let host = url.host {
                    if host == "oauth-callback" { return true }
                    if host == "localhost" { return url.path == "/oauth-callback" }
                    return false
                } else {
                    // No host case; treat as oauth-callback only if path is "/oauth-callback" or empty
                    return url.path.isEmpty || url.path == "/oauth-callback"
                }
            }()
            guard isOAuthCallback else { return }

            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            let items = components.queryItems ?? []
            let code = items.first(where: { $0.name == "code" })?.value
            let state = items.first(where: { $0.name == "state" })?.value

            // TODO: If you store a pending state, verify it here before proceeding.
            if let code {
                Task {
                    await self.handleOAuthCode(code: code)
                }
            } else {
                print("[OAuth] Missing authorization code in callback URL: \(url.absoluteString)")
            }
        }
        .onAppear {
            let token = UserDefaults.standard.string(forKey: "strava_access_token")
            isStravaConnected = (token?.isEmpty == false)

            stravaAuth.onAuthSuccess = {
                DispatchQueue.main.async {
                    self.isStravaConnected = true
                }
            }
        }
        .analyticsScreen("Home")
    }

    @MainActor
    private func handleOAuthCode(code: String) async {
        // Delegate to your auth manager. If your manager provides an async API, call it directly.
        // If it provides a completion-based API, wrap it in withCheckedContinuation.
        if let asyncExchange = (stravaAuth as AnyObject) as? Any {
            // Prefer an async API if available on the manager; replace with your real call
        }

        // Fallback: call a presumed async function on stravaAuth
        await stravaAuth.exchangeCodeForToken(code: code)

        // On success, update UI state if needed
        let token = UserDefaults.standard.string(forKey: "strava_access_token")
        isStravaConnected = (token?.isEmpty == false)
        stravaAuth.onAuthSuccess?()
    }

    private func hasUsableRouteData(_ parser: RouteParser) -> Bool {
        !parser.routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        parser.totalMiles > 0 ||
        parser.totalElevFt > 0 ||
        !parser.segments.isEmpty
    }
}

struct ElevationHeroShape: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 60

            ZStack(alignment: .bottom) {
                Path { p in
                    p.move(to: .init(x: 0, y: h))
                    p.addLine(to: .init(x: w * 0.10, y: h * 0.90))
                    p.addLine(to: .init(x: w * 0.25, y: h * 0.65))
                    p.addLine(to: .init(x: w * 0.40, y: h * 0.30))
                    p.addLine(to: .init(x: w * 0.52, y: h * 0.10))
                    p.addLine(to: .init(x: w * 0.62, y: h * 0.28))
                    p.addLine(to: .init(x: w * 0.72, y: h * 0.55))
                    p.addLine(to: .init(x: w * 0.82, y: h * 0.22))
                    p.addLine(to: .init(x: w * 0.92, y: h * 0.08))
                    p.addLine(to: .init(x: w, y: h * 0.30))
                    p.addLine(to: .init(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.cbAccent.opacity(0.35), Color.cbAccent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { p in
                    p.move(to: .init(x: 0, y: h))
                    p.addLine(to: .init(x: w * 0.10, y: h * 0.90))
                    p.addLine(to: .init(x: w * 0.25, y: h * 0.65))
                    p.addLine(to: .init(x: w * 0.40, y: h * 0.30))
                    p.addLine(to: .init(x: w * 0.52, y: h * 0.10))
                    p.addLine(to: .init(x: w * 0.62, y: h * 0.28))
                    p.addLine(to: .init(x: w * 0.72, y: h * 0.55))
                    p.addLine(to: .init(x: w * 0.82, y: h * 0.22))
                    p.addLine(to: .init(x: w * 0.92, y: h * 0.08))
                    p.addLine(to: .init(x: w, y: h * 0.30))
                }
                .stroke(
                    Color.cbAccent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: w * 0.92 - w / 2, y: -(h - h * 0.08) + h / 2)
            }
            .frame(height: h)
        }
        .frame(height: 60)
    }
}

