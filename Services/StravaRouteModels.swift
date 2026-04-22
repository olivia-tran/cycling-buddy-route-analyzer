import Foundation

struct StravaRouteResponse: Decodable {

    let id: Int64
    let name: String
    let distance: Double?
    let elevation_gain: Double?
    let segments: [StravaRouteSegment]?
}

struct StravaRouteSegment: Decodable {

    let id: Int64?
    let name: String
    let distance: Double?
    let average_grade: Double?
    let elevation_high: Double?
    let elevation_low: Double?
}
