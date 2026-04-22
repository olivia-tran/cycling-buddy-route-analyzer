import Foundation
import AuthenticationServices
import UIKit
import Combine

final class StravaAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    private let clientId = "186069"
    private let redirectURI = "cyclingbuddy://localhost/oauth-callback"
    private let scope = "read"

    private var oauthState: String = ""
    private var authSession: ASWebAuthenticationSession?

    var onAuthSuccess: (() -> Void)?

    // Notify UI when we hit Strava's rate limits (HTTP 429)
    var onRateLimited: (() -> Void)?

    // Per-user, in-app daily cap for analyses (can be tuned)
    private let dailyAnalysisCap: Int = 15

    func startOAuth() {
        let state = UUID().uuidString
        oauthState = state

        guard let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedState = state.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("[OAuth] Failed to encode redirect URI, state, or scope")
            return
        }

        let webAuthURLString = "https://www.strava.com/oauth/authorize?client_id=\(clientId)&response_type=code&redirect_uri=\(encodedRedirectURI)&approval_prompt=auto&scope=\(encodedScope)&state=\(encodedState)"
        let mobileAuthURLString = "strava://oauth/mobile/authorize?client_id=\(clientId)&response_type=code&redirect_uri=\(encodedRedirectURI)&approval_prompt=auto&scope=\(encodedScope)&state=\(encodedState)"

        print("[OAuth] startOAuth")
        print("[OAuth] Main thread:", Thread.isMainThread)
        print("[OAuth] webAuthURLString:", webAuthURLString)
        print("[OAuth] mobileAuthURLString:", mobileAuthURLString)

        DispatchQueue.main.async {
            self.tryMobileOrFallbackToWeb(
                mobileAuthURLString: mobileAuthURLString,
                webAuthURLString: webAuthURLString
            )
        }
    }

    private func tryMobileOrFallbackToWeb(mobileAuthURLString: String, webAuthURLString: String) {
        guard let mobileURL = URL(string: mobileAuthURLString) else {
            print("[OAuth] Invalid mobile auth URL, falling back to web")
            presentWebAuth(with: webAuthURLString)
            return
        }

        let canOpen = UIApplication.shared.canOpenURL(mobileURL)
        print("[OAuth] canOpenURL(strava://...):", canOpen)

        if canOpen {
            UIApplication.shared.open(mobileURL) { success in
                print("[OAuth] Open Strava app result:", success)
                if !success {
                    print("[OAuth] Falling back to web because open() failed")
                    self.presentWebAuth(with: webAuthURLString)
                }
            }
        } else {
            print("[OAuth] Falling back to web because Strava app is not available")
            presentWebAuth(with: webAuthURLString)
        }
    }

    private func presentWebAuth(with webAuthURLString: String) {
        guard let authURL = URL(string: webAuthURLString),
              let callbackScheme = URL(string: redirectURI)?.scheme else {
            print("[OAuth] Invalid web auth URL or callback scheme")
            return
        }

        print("[OAuth] Presenting web auth with scheme:", callbackScheme)

        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }

            if let error = error {
                print("[OAuth] Web auth error:", error.localizedDescription)
                return
            }

            guard let callbackURL else {
                print("[OAuth] No callback URL returned")
                return
            }

            print("[OAuth] Web auth callback URL:", callbackURL.absoluteString)
            self.handleCallback(callbackURL)
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false

        let started = authSession?.start() ?? false
        print("[OAuth] ASWebAuthenticationSession started:", started)
    }

    private func handleCallback(_ callbackURL: URL) {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            print("[OAuth] Failed to parse callback URL")
            return
        }

        if let err = components.queryItems?.first(where: { $0.name == "error" })?.value {
            print("[OAuth] OAuth returned error:", err)
            return
        }

        let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard returnedState == oauthState else {
            print("[OAuth] State mismatch. Expected:", oauthState, "Got:", returnedState ?? "nil")
            return
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("[OAuth] No code found in callback")
            return
        }

        print("[OAuth] Exchanging code for token")
        // Optional: gate with in-app daily cap before calling Strava
        if !canPerformAnalysisToday() {
            print("[RateLimit] In-app daily cap reached. Ask user to try again tomorrow.")
            self.onRateLimited?()
            return
        }
        recordAnalysisAttempt()
        Task { [weak self] in
            await self?.exchangeCodeForToken(code: code)
        }
    }

    // Async version accessible from outside this type (default internal)
    func exchangeCodeForToken(code: String) async {
        let clientSecret = "f7534a36d7e880c7e81d8abf730b648908d6cb09"

        guard let url = URL(string: "https://www.strava.com/api/v3/oauth/token") else {
            print("[OAuth] Invalid token endpoint URL")
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]

        req.httpBody = body
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("[OAuth] Token exchange failed with status:", httpResponse.statusCode)
                if let raw = String(data: data, encoding: .utf8) { print("[OAuth] Body:", raw) }
                return
            }

            struct TokenResponse: Decodable {
                let access_token: String
                let refresh_token: String
                let expires_at: TimeInterval
            }

            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            UserDefaults.standard.set(token.access_token, forKey: "strava_access_token")
            UserDefaults.standard.set(token.refresh_token, forKey: "strava_refresh_token")
            UserDefaults.standard.set(token.expires_at, forKey: "strava_expires_at")

            await MainActor.run {
                self.onAuthSuccess?()
            }
        } catch {
            print("[OAuth] Token exchange request failed:", error.localizedDescription)
        }
    }
    func refreshAccessTokenIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let now = Date().timeIntervalSince1970
        let expiresAt = UserDefaults.standard.double(forKey: "strava_expires_at")
        let secondsRemaining = expiresAt - now

        if secondsRemaining > 3600 {
            completion?(true)
            return
        }

        guard let refreshToken = UserDefaults.standard.string(forKey: "strava_refresh_token") else {
            print("[OAuth] No refresh token available")
            completion?(false)
            return
        }

        let clientSecret = "YOUR_CLIENT_SECRET_PLACEHOLDER"

        guard let url = URL(string: "https://www.strava.com/oauth/token") else {
            completion?(false)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        req.httpBody = body
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                print("[OAuth] Refresh token request failed:", error.localizedDescription)
                completion?(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[OAuth] Refresh token response missing HTTPURLResponse")
                completion?(false)
                return
            }
            if httpResponse.statusCode == 429 {
                print("[OAuth] Rate limited by Strava (429).")
                DispatchQueue.main.async { self.onRateLimited?() }
                completion?(false)
                return
            }

            guard let data else {
                print("[OAuth] Refresh token response body missing")
                completion?(false)
                return
            }

            struct RefreshResponse: Decodable {
                let access_token: String
                let refresh_token: String
                let expires_at: TimeInterval
            }

            do {
                let token = try JSONDecoder().decode(RefreshResponse.self, from: data)
                UserDefaults.standard.set(token.access_token, forKey: "strava_access_token")
                UserDefaults.standard.set(token.refresh_token, forKey: "strava_refresh_token")
                UserDefaults.standard.set(token.expires_at, forKey: "strava_expires_at")

                DispatchQueue.main.async {
                    self.onAuthSuccess?()
                }
                completion?(true)
            } catch {
                print("[OAuth] Failed to decode refresh response:", error.localizedDescription)
                completion?(false)
            }
        }.resume()
    }

    // MARK: - In-app daily analysis limiter
    private func todayKey() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    func canPerformAnalysisToday() -> Bool {
        let defaults = UserDefaults.standard
        let today = todayKey()
        let lastDate = defaults.string(forKey: "cb_lastCountDate")
        if lastDate != today {
            defaults.set(today, forKey: "cb_lastCountDate")
            defaults.set(0, forKey: "cb_dailyAnalysisCount")
            return true
        }
        let count = defaults.integer(forKey: "cb_dailyAnalysisCount")
        return count < dailyAnalysisCap
    }

    func recordAnalysisAttempt() {
        let defaults = UserDefaults.standard
        let today = todayKey()
        let lastDate = defaults.string(forKey: "cb_lastCountDate")
        if lastDate != today {
            defaults.set(today, forKey: "cb_lastCountDate")
            defaults.set(1, forKey: "cb_dailyAnalysisCount")
        } else {
            let count = defaults.integer(forKey: "cb_dailyAnalysisCount")
            defaults.set(count + 1, forKey: "cb_dailyAnalysisCount")
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        for scene in scenes {
            if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
        }

        return ASPresentationAnchor()
    }
}//
//  StravaAuthManager.swift
//  CyclingBuddy
//
//  Created by Olivia Mac on 3/15/26.
//


