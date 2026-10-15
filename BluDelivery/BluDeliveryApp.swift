import SwiftUI

/// Launch configuration driven by the test bundle.
///
/// UI tests need to put the app into a known state without clicking their way there. Launch
/// arguments are how that's done on Apple platforms: the test passes flags, the app reads them at
/// startup. The alternative — driving setup through the UI — makes every test depend on the
/// correctness of screens it isn't testing.
enum LaunchConfig {
    static var isUITesting: Bool { args.contains("-UITests") }
    static var startsSignedIn: Bool { args.contains("-SignedIn") }
    static var seedsCart: Bool { args.contains("-SeedCart") }
    /// Forces the simulated payment call to fail, so the error path is reachable deterministically.
    static var failsCheckout: Bool { args.contains("-FailCheckout") }
    /// Removes artificial latency so tests aren't paying for a demo animation.
    static var isFast: Bool { args.contains("-FastMode") }

    private static var args: [String] { ProcessInfo.processInfo.arguments }
}

@main
struct BluDeliveryApp: App {
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onAppear {
                    if LaunchConfig.isUITesting {
                        // Disable animations so the suite isn't waiting on transitions. Doing this
                        // via a launch flag rather than globally keeps the shipped app unchanged.
                        UIView.setAnimationsEnabled(false)
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var session: Session

    var body: some View {
        if session.isSignedIn {
            ProductListView()
        } else {
            LoginView()
        }
    }
}
