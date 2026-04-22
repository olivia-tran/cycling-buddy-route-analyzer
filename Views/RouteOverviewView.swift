import SwiftUI
import FirebaseAnalytics
import UIKit

struct RouteOverviewView: View {
    @ObservedObject var parser: RouteParser
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.cbBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Route map placeholder ─────────────────────────────
                    RouteMapPlaceholder(routeName: parser.routeName)

                    // ── Summary stats ─────────────────────────────────────
                    HStack(spacing: 8) {
                        StatChip(value: String(format: "%.1f", parser.totalMiles),
                                 unit: "MILES",
                                 color: .cbText)
                        StatChip(value: parser.totalElevFt > 0
                                    ? "\(parser.totalElevFt.formatted())"
                                    : "—",
                                 unit: "ELEV FT",
                                 color: .cbAccent)
                        if let desc = parser.steepestDescent {
                            StatChip(value: String(format: "%.1f%%", desc.avgGradePercent),
                                     unit: "MAX DESC",
                                     color: .red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // ── Climbs section ────────────────────────────────────
                    sectionHeader("⛰  CLIMBS — HARDEST FIRST")

                    if parser.climbs.isEmpty {
                        Text("No significant climbs found.")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.cbMuted)
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(parser.climbs) { climb in
                                NavigationLink(destination: ClimbDetailView(segment: climb, routeURLString: parser.routeURLString)) {
                                    ClimbCard(segment: climb)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open details for climb \(climb.name)")
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Steepest descents list ─────────────────────────────
                    let descents = parser.segments.filter { $0.isDescent }.sorted { $0.avgGradePercent < $1.avgGradePercent }
                    if !descents.isEmpty {
                        sectionHeader("⬇  STEEPEST DESCENTS")

                        VStack(spacing: 8) {
                            ForEach(descents) { descent in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(descent.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.cbMuted)
                                        Text("\(String(format: "%.2f", descent.distanceMiles)) MI  ·  \(abs(descent.elevDiffFt)) FT DROP")
                                            .font(.custom("DMMono-Medium", size: 12))
                                            .tracking(1)
                                            .foregroundColor(.cbText)
                                            .minimumScaleFactor(0.9)
                                    }
                                    Spacer()
                                    Text(String(format: "%.1f%%", descent.avgGradePercent))
                                        .font(.custom("BebasNeue-Regular", size: 28))
                                        .foregroundColor(.red)
                                }
                                .padding(14)
                                .background(Color.red.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                                )
                                .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if let url = URL(string: parser.routeURLString), !parser.routeURLString.isEmpty {
                        Button {
                            // Analytics tap
                            Analytics.logEvent("share_ride_tap", parameters: [
                                "route_name": parser.routeName as NSObject
                            ])

                            let friendlyMessage = "Join me for this ride: \(parser.routeName)\n\(parser.routeURLString)"
                            var items: [Any] = [friendlyMessage]
                            if let validURL = URL(string: parser.routeURLString), validURL.scheme != nil, validURL.host != nil {
                                items.append(validURL)
                            }

                            DispatchQueue.main.async {
                                guard let scene = UIApplication.shared.connectedScenes
                                    .compactMap({ $0 as? UIWindowScene })
                                    .first(where: { $0.activationState == .foregroundActive }) else { return }
                                let window = scene.keyWindow ?? scene.windows.first(where: { $0.isHidden == false }) ?? scene.windows.first
                                guard let root = window?.rootViewController else { return }

                                func topVC(from base: UIViewController) -> UIViewController {
                                    if let nav = base as? UINavigationController, let vis = nav.visibleViewController { return topVC(from: vis) }
                                    if let tab = base as? UITabBarController, let sel = tab.selectedViewController { return topVC(from: sel) }
                                    if let presented = base.presentedViewController { return topVC(from: presented) }
                                    return base
                                }
                                let top = topVC(from: root)
                                let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                                if let pop = activityVC.popoverPresentationController {
                                    pop.sourceView = top.view
                                    pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 1, width: 1, height: 1)
                                    pop.permittedArrowDirections = []
                                }
                                top.present(activityVC, animated: true)
                            }
                        } label: {
                            Text("Share this ride with friends?")
                                .font(.custom("BebasNeue-Regular", size: 20))
                                .tracking(3)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.cbAccent)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .accessibilityLabel("Share this route")
                        .accessibilityHint("Opens the share sheet to invite friends")
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Cycling Buddy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .analyticsScreen("Overview")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.custom("DMMono-Regular", size: 9))
                .tracking(3)
                .foregroundColor(.cbMuted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: – Sub-views

struct RouteMapPlaceholder: View {
    let routeName: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Dark map background with subtle grid
            Color(hex: "#0d1520")
                .overlay(
                    Canvas { ctx, size in
                        let step: CGFloat = 30
                        var x: CGFloat = 0
                        while x < size.width {
                            ctx.stroke(Path { p in p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height)) },
                                       with: .color(.white.opacity(0.04)), lineWidth: 1)
                            x += step
                        }
                        var y: CGFloat = 0
                        while y < size.height {
                            ctx.stroke(Path { p in p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y)) },
                                       with: .color(.white.opacity(0.04)), lineWidth: 1)
                            y += step
                        }
                    }
                )

            // Decorative route line
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { p in
                    p.move(to: .init(x: w * 0.06, y: h * 0.75))
                    p.addQuadCurve(to: .init(x: w * 0.35, y: h * 0.30),
                                   control: .init(x: w * 0.18, y: h * 0.55))
                    p.addQuadCurve(to: .init(x: w * 0.60, y: h * 0.12),
                                   control: .init(x: w * 0.50, y: h * 0.22))
                    p.addQuadCurve(to: .init(x: w * 0.78, y: h * 0.38),
                                   control: .init(x: w * 0.72, y: h * 0.20))
                    p.addQuadCurve(to: .init(x: w * 0.91, y: h * 0.45),
                                   control: .init(x: w * 0.86, y: h * 0.50))
                }
                .stroke(
                    LinearGradient(
                        colors: [.green, .yellow, .orange, .red],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Start dot
                Circle().fill(Color.green).frame(width: 10, height: 10)
                    .position(x: w * 0.06, y: h * 0.75)
                // End dot
                Circle().fill(Color.red).frame(width: 10, height: 10)
                    .position(x: w * 0.91, y: h * 0.45)
            }

            // Route name pill
            Text(routeName.uppercased())
                .font(.custom("DMMono-Regular", size: 9))
                .tracking(1)
                .foregroundColor(.cbAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(12)
        }
        .frame(height: 200)
    }
}

struct StatChip: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom("BebasNeue-Regular", size: 20))
                .tracking(1)
                .foregroundColor(color)
                .minimumScaleFactor(0.9)
                .lineLimit(1)
            Text(unit)
                .font(.custom("DMMono-Regular", size: 8))
                .tracking(1)
                .foregroundColor(.cbMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(12)
    }
}

struct ClimbCard: View {
    let segment: RouteSegment

    var categoryColor: Color {
        switch segment.category {
        case .hc:   return .red
        case .cat1: return .cbAccent
        case .cat2: return .orange
        default:    return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left accent bar
            Rectangle()
                .fill(categoryColor)
                .frame(width: 3)
                .cornerRadius(2)

            // Category badge
            Text(segment.category.rawValue)
                .font(.custom("BebasNeue-Regular", size: 13))
                .tracking(1)
                .foregroundColor(categoryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.12))
                .cornerRadius(6)

            // Name + meta
            VStack(alignment: .leading, spacing: 3) {
                Text(segment.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cbMuted)
                    .lineLimit(1)
                Text("\(String(format: "%.2f", segment.distanceMiles)) MI  ·  \(segment.elevDiffFt) FT GAIN")
                    .font(.custom("DMMono-Medium", size: 12))
                    .tracking(1)
                    .foregroundColor(.cbText)
                    .minimumScaleFactor(0.9)
            }

            Spacer()

            // Grade
            Text(String(format: "%.1f%%", segment.avgGradePercent))
                .font(.custom("BebasNeue-Regular", size: 22))
                .tracking(1)
                .foregroundColor(categoryColor)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.cbMuted)
        }
        .padding(.vertical, 12)
        .padding(.trailing, 14)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(14)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

