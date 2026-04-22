import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct CyclingBuddyApp: App {
    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #else
        // FirebaseCore not available in this build configuration; skip configuration.
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
