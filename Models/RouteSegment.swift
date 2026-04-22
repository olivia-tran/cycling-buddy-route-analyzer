import Foundation

struct RouteSegment: Identifiable {
    let id = UUID()
    let name: String
    let distanceMiles: Double
    let elevDiffFt: Int
    let avgGradePercent: Double

    var isClimb: Bool {
        avgGradePercent >= 2.0 && elevDiffFt > 50
    }

    var isDescent: Bool {
        avgGradePercent <= -4.0
    }

    var category: ClimbCategory {
        guard isClimb else { return .none }
        let score = distanceMiles * 1.609 * abs(avgGradePercent)
        switch score {
        case 128...:    return .hc
        case 64..<128:  return .cat1
        case 32..<64:   return .cat2
        case 16..<32:   return .cat3
        default:        return .cat4
        }
    }
}

enum ClimbCategory: String {
    case hc   = "HC"
    case cat1 = "CAT 1"
    case cat2 = "CAT 2"
    case cat3 = "CAT 3"
    case cat4 = "CAT 4"
    case none = ""
}
