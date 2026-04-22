import SwiftUI
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
import UIKit

extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topMostViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RouteComparisonView: View {
    @State private var isSharing = false

    let parserA: RouteParser
    let parserB: RouteParser

    private var distanceChangePercent: Double? {
        guard parserA.totalMiles > 0, parserB.totalMiles > 0 else { return nil }
        let change = ((parserB.totalMiles - parserA.totalMiles) / parserA.totalMiles) * 100
        return change
    }

    private var elevationChangePercent: Double? {
        guard parserA.totalElevFt > 0, parserB.totalElevFt > 0 else { return nil }
        let a = Double(parserA.totalElevFt)
        let b = Double(parserB.totalElevFt)
        let change = ((b - a) / a) * 100
        return change
    }

    private var hardClimbsA: [RouteSegment] {
        parserA.segments.filter { $0.isClimb }
    }

    private var hardClimbsB: [RouteSegment] {
        parserB.segments.filter { $0.isClimb }
    }

    private var steepDescentsA: [RouteSegment] {
        parserA.segments.filter { $0.isDescent }
    }

    private var steepDescentsB: [RouteSegment] {
        parserB.segments.filter { $0.isDescent }
    }
    
    private var routeAName: String { parserA.routeName.isEmpty ? "Route A" : parserA.routeName }
    private var routeBName: String { parserB.routeName.isEmpty ? "Route B" : parserB.routeName }
    
    // Added helpers for climbs totals and medians
    private var climbsA: [RouteSegment] { parserA.segments.filter { $0.isClimb } }
    private var climbsB: [RouteSegment] { parserB.segments.filter { $0.isClimb } }

    private var totalClimbGainA: Int { climbsA.reduce(0) { $0 + max(0, $1.elevDiffFt) } }
    private var totalClimbGainB: Int { climbsB.reduce(0) { $0 + max(0, $1.elevDiffFt) } }

    private var medianClimbGradeA: Double { median(of: climbsA.map { $0.avgGradePercent }) }
    private var medianClimbGradeB: Double { median(of: climbsB.map { $0.avgGradePercent }) }
    private var medianClimbMilesA: Double { median(of: climbsA.map { $0.distanceMiles }) }
    private var medianClimbMilesB: Double { median(of: climbsB.map { $0.distanceMiles }) }

    private func median(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 { return (sorted[mid-1] + sorted[mid]) / 2 } else { return sorted[mid] }
    }
    
    // Verdict calculation
    private var verdictText: String {
        // Weighted heuristic: elevation (2x), hard climbs count (1.5x), distance (1x)
        let hardA = hardClimbsA.count
        let hardB = hardClimbsB.count
        let scoreA = (Double(parserA.totalElevFt) * 2.0) + (Double(hardA) * 1.5) + (parserA.totalMiles * 1.0)
        let scoreB = (Double(parserB.totalElevFt) * 2.0) + (Double(hardB) * 1.5) + (parserB.totalMiles * 1.0)
        if scoreA == 0 && scoreB == 0 { return "Not enough data to determine difficulty." }
        if scoreA > scoreB { return "\(routeAName) is likely harder overall." }
        if scoreB > scoreA { return "\(routeBName) is likely harder overall." }
        return "Both routes appear similar in overall difficulty."
    }
    
    var body: some View {
        ZStack {
            Color.cbBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Text("ROUTE COMPARISON")
                            .font(.custom("BebasNeue-Regular", size: 28))
                            .foregroundColor(.cbText)
                        VStack(spacing: 2) {
                            Text("\(parserA.routeName)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cbAccent)
                                .multilineTextAlignment(.center)
                            Text("vs")
                                .font(.custom("DMMono-Regular", size: 10))
                                .foregroundColor(.cbMuted)
                            Text("\(parserB.routeName)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cbAccent)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Verdict strip
                    HStack {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.green)
                        Text(verdictText)
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(.cbText)
                            .minimumScaleFactor(0.9)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.cbCard)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cbBorder, lineWidth: 1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Summary chips
                    HStack(spacing: 8) {
                        summaryChip(title: "LONGER", winner: parserA.totalMiles >= parserB.totalMiles ? routeAName : routeBName)
                        summaryChip(title: "MORE ELEV", winner: parserA.totalElevFt >= parserB.totalElevFt ? routeAName : routeBName)
                        summaryChip(title: "MORE CLIMBS", winner: climbsA.count >= climbsB.count ? routeAName : routeBName)
                        summaryChip(title: "STEEPER DESC", winner: (steepDescentsA.map{abs($0.avgGradePercent)}.max() ?? 0) >= (steepDescentsB.map{abs($0.avgGradePercent)}.max() ?? 0) ? routeAName : routeBName)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Totals comparison
                    sectionHeader("DISTANCE & ELEVATION")
                    HStack(spacing: 8) {
                        StatChip(value: String(format: "%.1f", parserA.totalMiles), unit: "\(routeAName.uppercased()) MILES", color: .cbText)
                        StatChip(value: String(format: "%.1f", parserB.totalMiles), unit: "\(routeBName.uppercased()) MILES", color: .cbText)
                    }
                    .padding(.horizontal, 16)
                    HStack(spacing: 8) {
                        StatChip(value: parserA.totalElevFt > 0 ? "\(parserA.totalElevFt.formatted())" : "—", unit: "\(routeAName.uppercased()) ELEV FT", color: .cbAccent)
                        StatChip(value: parserB.totalElevFt > 0 ? "\(parserB.totalElevFt.formatted())" : "—", unit: "\(routeBName.uppercased()) ELEV FT", color: .cbAccent)
                    }
                    .padding(.horizontal, 16)

                    if let d = distanceChangePercent {
                        comparisonBadge(title: "Distance change", value: String(format: "%+.1f%%", d), color: .cbAccent)
                    }
                    if let e = elevationChangePercent {
                        comparisonBadge(title: "Elevation change", value: String(format: "%+.1f%%", e), color: .cbAccent)
                    }

                    // Climbs comparison
                    sectionHeader("HARD CLIMBS")
                    Text("Count = number of climbs (avg grade ≥ 2% and >50 ft gain)")
                        .font(.custom("DMMono-Regular", size: 10))
                        .foregroundColor(.cbText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    if hardClimbsA.isEmpty && hardClimbsB.isEmpty {
                        comparisonBadge(title: "No climbs detected", value: "—", color: .cbAccent)
                    }
                    comparisonRow(label: "Count", a: hardClimbsA.count, b: hardClimbsB.count)
                    
                    // Longest climb (miles at % grade)
                    let longestA = hardClimbsA.max(by: { $0.distanceMiles < $1.distanceMiles })
                    let longestB = hardClimbsB.max(by: { $0.distanceMiles < $1.distanceMiles })
                    detailedRow(label: "Longest climb", a: longestA != nil ? String(format: "%.2f mi @ %.1f%%", longestA!.distanceMiles, max(0, longestA!.avgGradePercent)) : "—", b: longestB != nil ? String(format: "%.2f mi @ %.1f%%", longestB!.distanceMiles, max(0, longestB!.avgGradePercent)) : "—")

                    // Total distance of climbs above 4%
                    let climbsAbove4A = parserA.segments.filter { $0.avgGradePercent >= 4.0 && $0.elevDiffFt > 50 }
                    let climbsAbove4B = parserB.segments.filter { $0.avgGradePercent >= 4.0 && $0.elevDiffFt > 50 }
                    let totalClimbMilesA = climbsAbove4A.reduce(0.0) { $0 + $1.distanceMiles }
                    let totalClimbMilesB = climbsAbove4B.reduce(0.0) { $0 + $1.distanceMiles }
                    detailedRow(label: "Total climb distance ≥4%", a: String(format: "%.2f mi", totalClimbMilesA), b: String(format: "%.2f mi", totalClimbMilesB))

                    // Descents comparison
                    sectionHeader("STEEP DESCENTS")
                    Text("Count = number of descents (avg grade ≤ -4%)")
                        .font(.custom("DMMono-Regular", size: 10))
                        .foregroundColor(.cbText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    if steepDescentsA.isEmpty && steepDescentsB.isEmpty {
                        comparisonBadge(title: "No steep descents detected", value: "—", color: .cbAccent)
                    }
                    // Steepest descent (% grade)
                    let steepestA = steepDescentsA.max(by: { abs($0.avgGradePercent) < abs($1.avgGradePercent) })
                    let steepestB = steepDescentsB.max(by: { abs($0.avgGradePercent) < abs($1.avgGradePercent) })
                    detailedRow(label: "Steepest descent", a: steepestA != nil ? String(format: "%.1f%%", abs(steepestA!.avgGradePercent)) : "—", b: steepestB != nil ? String(format: "%.1f%%", abs(steepestB!.avgGradePercent)) : "—")

                    // Total distance of descents steeper than -4%
                    let descentsBelowNeg4A = parserA.segments.filter { $0.avgGradePercent <= -4.0 }
                    let descentsBelowNeg4B = parserB.segments.filter { $0.avgGradePercent <= -4.0 }
                    let totalDescentMilesA = descentsBelowNeg4A.reduce(0.0) { $0 + $1.distanceMiles }
                    let totalDescentMilesB = descentsBelowNeg4B.reduce(0.0) { $0 + $1.distanceMiles }
                    detailedRow(label: "Total descent distance ≤-4%", a: String(format: "%.2f mi", totalDescentMilesA), b: String(format: "%.2f mi", totalDescentMilesB))
                    
                    // Top 3 climbs side-by-side
                    sectionHeader("TOP 3 CLIMBS")
                    HStack(alignment: .top, spacing: 8) {
                        topClimbsColumn(title: routeAName, climbs: climbsA)
                        topClimbsColumn(title: routeBName, climbs: climbsB)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    
                    // Actions
                    HStack(spacing: 8) {
                        if let urlA = URL(string: parserA.routeURLString), !parserA.routeURLString.isEmpty {
                            Button {
#if canImport(FirebaseAnalytics)
                                Analytics.logEvent("open_in_strava_tap", parameters: [
                                    "context": "comparison" as NSObject,
                                    "route_name": routeAName as NSObject
                                ])
#endif
                                UIApplication.shared.open(urlA)
                            } label: {
                                Text("Open \(routeAName)")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.cbAccent)
                                    .cornerRadius(10)
                                    .accessibilityLabel("Open \(routeAName) in Strava")
                                    .accessibilityHint("Opens the route link in your browser or the Strava app")
                            }
                        }
                        if let urlB = URL(string: parserB.routeURLString), !parserB.routeURLString.isEmpty {
                            Button {
#if canImport(FirebaseAnalytics)
                                Analytics.logEvent("open_in_strava_tap", parameters: [
                                    "context": "comparison" as NSObject,
                                    "route_name": routeBName as NSObject
                                ])
#endif
                                UIApplication.shared.open(urlB)
                            } label: {
                                Text("Open \(routeBName)")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.cbAccent)
                                    .cornerRadius(10)
                                    .accessibilityLabel("Open \(routeBName) in Strava")
                                    .accessibilityHint("Opens the route link in your browser or the Strava app")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if let urlA = URL(string: parserA.routeURLString), let urlB = URL(string: parserB.routeURLString) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            print("[Share] Button tapped")
#if canImport(FirebaseAnalytics)
Analytics.logEvent("share_comparison_tap", parameters: [
    "route_a": routeAName as NSObject,
    "route_b": routeBName as NSObject
])
#endif

let friendlyMessage = "I'm planning a ride! \(routeAName) vs \(routeBName) — \(verdictText)\nLinks: \(parserA.routeURLString), \(parserB.routeURLString)"

// Build activity items safely: always include message, include only valid URLs
var activityItems: [Any] = [friendlyMessage]
if urlA.scheme != nil && urlA.host != nil {
    activityItems.append(urlA)
}
if urlB.scheme != nil && urlB.host != nil {
    activityItems.append(urlB)
}
print("[Share] Items count:", activityItems.count)

DispatchQueue.main.async {
    print("[Share] Enter main async")
    // Find a foreground active scene
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }) else {
            print("[Share] No foregroundActive scene found")
            return
    }
    print("[Share] Found scene")

    // Get a window to anchor presentation; prefer keyWindow, fallback to first visible/any window
    let window = scene.keyWindow ?? scene.windows.first(where: { $0.isHidden == false }) ?? scene.windows.first
    if window == nil { print("[Share] No window found in scene") }

    guard let root = window?.rootViewController else {
        print("[Share] No rootViewController found on any window")
        return
    }
    print("[Share] Found root:", type(of: root))

    // Find the top-most view controller
    func topViewController(from base: UIViewController) -> UIViewController {
        if let nav = base as? UINavigationController, let visible = nav.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = base.presentedViewController {
            return topViewController(from: presented)
        }
        return base
    }
    var top = topViewController(from: root)
    print("[Share] Top VC:", type(of: top))

    let presentActivity: () -> Void = {
        print("[Share] Presenting activity VC")
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let pop = activityVC.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 1, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }

    if top.presentedViewController != nil {
        print("[Share] Something already presented, dismissing first")
        top.dismiss(animated: false) {
            top = topViewController(from: root)
            print("[Share] After dismiss, new top VC:", type(of: top))
            presentActivity()
        }
    } else {
        presentActivity()
    }
}
                        } label: {
                            Text("Share comparison")
                                .font(.custom("BebasNeue-Regular", size: 18))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cbAccent)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .accessibilityLabel("Share route comparison")
                        .accessibilityHint("Opens the share sheet with both route links and summary")
                    }
                    
                    // Safety note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SAFETY & TRAFFIC")
                            .font(.custom("DMMono-Regular", size: 9))
                            .tracking(3)
                            .foregroundColor(.cbMuted)
                        Text("Traffic conditions, bike lanes, or road hazards are not available from these route pages. Use caution, follow local laws, and ride within your limits.")
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(.cbText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Compare Routes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .analyticsScreen("Compare")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.custom("DMMono-Regular", size: 9))
                .tracking(3)
                .foregroundColor(.green)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func comparisonBadge(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.custom("DMMono-Regular", size: 10))
                .foregroundColor(.cbAccent)
            Spacer()
            Text(value)
                .font(.custom("BebasNeue-Regular", size: 18))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func summaryChip(title: String, winner: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.custom("DMMono-Regular", size: 8))
                .foregroundColor(.cbAccent)
            Text(winner)
                .font(.custom("DMMono-Regular", size: 10))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func comparisonRow<T: CustomStringConvertible>(label: String, a: T, b: T, isDouble: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cbAccent)
            Spacer()
            Text("\(routeAName): \(a)")
                .font(.custom("DMMono-Regular", size: 11))
                .foregroundColor(.white)
            Text("\(routeBName): \(b)")
                .font(.custom("DMMono-Regular", size: 11))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
    
    @ViewBuilder
    private func detailedRow(label: String, a: String, b: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cbAccent)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(routeAName): \(a)")
                    .font(.custom("DMMono-Regular", size: 11))
                    .foregroundColor(.white)
                Text("\(routeBName): \(b)")
                    .font(.custom("DMMono-Regular", size: 11))
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
    
    @ViewBuilder
    private func topClimbsColumn(title: String, climbs: [RouteSegment]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("DMMono-Regular", size: 10))
                .foregroundColor(.cbAccent)
            let top = climbs.sorted { ($0.elevDiffFt, $0.distanceMiles) > ($1.elevDiffFt, $1.distanceMiles) }.prefix(3)
            if top.isEmpty {
                Text("No climbs")
                    .font(.custom("DMMono-Regular", size: 10))
                    .foregroundColor(.cbText)
            } else {
                ForEach(Array(top.enumerated()), id: \.offset) { _, seg in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(seg.name)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.cbMuted)
                            .lineLimit(1)
                        Text(String(format: "%.2f mi  ·  %d ft  ·  %.1f%%", seg.distanceMiles, seg.elevDiffFt, seg.avgGradePercent))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.cbCard)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cbBorder, lineWidth: 1))
                    .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

