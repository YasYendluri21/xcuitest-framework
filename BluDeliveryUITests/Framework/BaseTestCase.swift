import XCTest

/// Shared setup for every UI test.
class BaseTestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // A UI test that keeps running after its first failure produces a cascade of misleading
        // secondary failures. Stop at the first one; the trace tells the rest of the story.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Attach the hierarchy on failure only. Attaching it always bloats the .xcresult for runs
        // nobody will look at.
        if let app, testRun?.failureCount ?? 0 > 0 {
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "element-hierarchy"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    /// Wraps a block in an xcresult activity, so the report reads as steps rather than a wall of
    /// assertions. Worth the three lines — it's what makes a CI failure legible to someone who
    /// didn't write the test.
    func step<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        try XCTContext.runActivity(named: name) { _ in try body() }
    }
}
