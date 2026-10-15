import XCTest

/// Launches the app in a known state.
///
/// Every test starts from a configured launch rather than driving the UI to get somewhere. A test
/// for the checkout total shouldn't fail because the login screen changed — seeding state through
/// launch arguments keeps each test's failure surface to the thing it actually tests.
struct AppLauncher {
    private var arguments: [String] = ["-UITests", "-FastMode"]

    func signedIn() -> Self { adding("-SignedIn") }
    func withSeededCart() -> Self { adding("-SeedCart").adding("-SignedIn") }
    func failingCheckout() -> Self { adding("-FailCheckout") }

    private func adding(_ argument: String) -> Self {
        var copy = self
        if !copy.arguments.contains(argument) { copy.arguments.append(argument) }
        return copy
    }

    @discardableResult
    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
}
