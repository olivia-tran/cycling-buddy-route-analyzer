import SwiftUI
import Charts
import FirebaseAnalytics

struct ClimbDetailView: View {
    let segment: RouteSegment
    let routeURLString: String
    @Environment(\.openURL) private var openURL

    var categoryColor: Color {
        switch segment.category {
        case .hc:   return .red
        case .cat1: return .cbAccent
        case .cat2: return .orange
        default:    return .yellow
        }
    }

    // Simulated elevation profile points based on grade
    var elevationPoints: [ElevPoint] {
        let steps = 20
        var points: [ElevPoint] = []
        let gainPerStep = Double(segment.elevDiffFt) / Double(steps)
        var elev = 0.0
        for i in 0...steps {
            // Add slight variance to make the chart look natural
            let noise = Double.random(in: -gainPerStep * 0.3 ... gainPerStep * 0.3)
            elev += gainPerStep + (i > 0 ? noise : 0)
            elev = max(0, elev)
            points.append(ElevPoint(index: i, elevation: elev))
        }
        return points
    }

    var estimatedMinutes: Int {
        // Rough estimate: 15 min/mile flat + 1 min per 50ft gain
        let baseMins = segment.distanceMiles * 15
        let climbMins = Double(segment.elevDiffFt) / 50.0
        return Int(baseMins + climbMins)
    }

    var body: some View {
        ZStack {
            Color.cbBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        Text(segment.category.rawValue)
                            .font(.custom("DMMono-Regular", size: 10))
                            .tracking(3)
                            .foregroundColor(categoryColor)
                            .padding(.bottom, 4)

                        Text(segment.name.uppercased())
                            .font(.custom("BebasNeue-Regular", size: 30))
                            .tracking(3)
                            .foregroundColor(.cbText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Climb name: \(segment.name)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.08), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    // ── Elevation chart ────────────────────────────────────
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(segment.elevDiffFt) FT ↑")
                            .font(.custom("DMMono-Regular", size: 9))
                            .tracking(1)
                            .foregroundColor(categoryColor)

                        Chart(elevationPoints) { point in
                            AreaMark(
                                x: .value("Distance", point.index),
                                y: .value("Elevation", point.elevation)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [categoryColor.opacity(0.3), categoryColor.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Distance", point.index),
                                y: .value("Elevation", point.elevation)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .yellow, categoryColor],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.cbCard)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cbBorder, lineWidth: 1))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // ── Big 3 stats ────────────────────────────────────────
                    HStack(spacing: 8) {
                        BigStat(value: String(format: "%.2f", segment.distanceMiles),
                                label: "MILES",
                                color: categoryColor)
                        BigStat(value: String(format: "%.1f%%", segment.avgGradePercent),
                                label: "AVG GRADE",
                                color: .yellow)
                        BigStat(value: "\(segment.elevDiffFt)",
                                label: "ELEV FT",
                                color: .green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // ── Detail rows ────────────────────────────────────────
                    VStack(spacing: 6) {
                        DetailRow(label: "CLIMB CATEGORY",
                                  value: segment.category.rawValue,
                                  valueColor: categoryColor)
                        DetailRow(label: "EST. CLIMB TIME",
                                  value: "~\(estimatedMinutes) MIN",
                                  valueColor: .cbText)
                        DetailRow(label: "STEEPEST SECTION (est.)",
                                  value: String(format: "%.1f%%", segment.avgGradePercent * 1.4),
                                  valueColor: .red)
                        DetailRow(label: "TOTAL DISTANCE",
                                  value: String(format: "%.2f mi", segment.distanceMiles),
                                  valueColor: .cbText)
                        DetailRow(label: "ELEVATION GAIN",
                                  value: "\(segment.elevDiffFt) ft",
                                  valueColor: .green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // ── CTA button ─────────────────────────────────────────
                    if let url = URL(string: routeURLString), !routeURLString.isEmpty {
                        Button {
                            Analytics.logEvent("open_in_strava_tap", parameters: [
                                "context": "climb_detail" as NSObject,
                                "segment_name": segment.name as NSObject
                            ])
                            openURL(url)
                        } label: {
                            HoverableAccentButtonLabel(text: "Open in Strava")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(16)
                        .padding(.top, 8)
                        .accessibilityLabel("Open this route in Strava")
                        .accessibilityHint("Opens the route link in your browser or the Strava app")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .analyticsScreen("ClimbDetail")
    }
}

// MARK: – Sub-views

struct BigStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("BebasNeue-Regular", size: 26))
                .tracking(1)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.custom("DMMono-Regular", size: 8))
                .tracking(1.5)
                .foregroundColor(.cbMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(14)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.custom("DMMono-Regular", size: 9))
                .tracking(1.5)
                .foregroundColor(.cbMuted)
            Spacer()
            Text(value)
                .font(.custom("DMMono-Medium", size: 11))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cbCard)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cbBorder, lineWidth: 1))
        .cornerRadius(10)
    }
}

struct ElevPoint: Identifiable {
    let id = UUID()
    let index: Int
    let elevation: Double
}

