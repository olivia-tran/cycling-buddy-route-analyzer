import Foundation

enum AppSecrets {

    static var stravaClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_ID") as? String ?? ""
    }

    static var stravaClientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_SECRET") as? String ?? ""
    }
}

