import SwiftUI
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

struct AnalyticsScreen: ViewModifier {
    let name: String
    func body(content: Content) -> some View {
        content.onAppear {
#if canImport(FirebaseAnalytics)
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: name as NSObject
            ])
#endif
        }
    }
}

extension View {
    func analyticsScreen(_ name: String) -> some View {
        self.modifier(AnalyticsScreen(name: name))
    }
}
