import XCTest

/// Synchronization primitives.
///
/// XCUITest gives you two things and neither is enough on its own. Queries are evaluated lazily, so
/// `app.buttons["x"]` doesn't touch the app until you ask it something — but the moment you ask,
/// it answers *now*, with no retry. And `waitForExistence(timeout:)` only covers existence: an
/// element can exist while being off-screen, disabled, or mid-animation.
///
/// So everything below builds on `XCTNSPredicateExpectation`, which polls, and expresses the
/// condition that actually matters rather than the one that's easiest to check. `Thread.sleep`
/// appears nowhere in this suite, and that is the point.
enum Wait {
    /// Default ceiling for a UI condition. Long enough for a slow simulator under CI load, short
    /// enough that a genuine hang fails the test rather than stalling the run.
    static let timeout: TimeInterval = 10

    /// Waits for an arbitrary predicate against an element, failing the test with context.
    @discardableResult
    static func predicate(
        _ format: String,
        arguments: [Any] = [],
        on element: XCUIElement,
        timeout: TimeInterval = Wait.timeout,
        describedAs description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format, argumentArray: arguments),
            object: element
        )

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

        if result != .completed {
            // Report what was actually observed. "Timed out" alone sends the next person to the
            // trace; "exists: false, hittable: false" usually tells them the answer immediately.
            XCTFail(
                """
                Timed out after \(timeout)s waiting for \(description).
                  exists: \(element.exists), hittable: \(element.exists ? String(element.isHittable) : "n/a")
                """,
                file: file,
                line: line
            )
            return false
        }

        return true
    }

    /// Element is present in the hierarchy. The weakest useful condition.
    @discardableResult
    static func exists(
        _ element: XCUIElement,
        timeout: TimeInterval = Wait.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        predicate("exists == true", on: element, timeout: timeout,
                  describedAs: "\(element.debugName) to exist", file: file, line: line)
    }

    /// Element is present *and* can receive a touch at its centre.
    ///
    /// This is the condition to wait on before interacting. An element that exists but isn't
    /// hittable is the most common source of a tap that silently lands on nothing — it's behind a
    /// keyboard, scrolled off-screen, or still animating in.
    @discardableResult
    static func hittable(
        _ element: XCUIElement,
        timeout: TimeInterval = Wait.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        predicate("exists == true AND isHittable == true", on: element, timeout: timeout,
                  describedAs: "\(element.debugName) to be hittable", file: file, line: line)
    }

    /// Element has gone. Used to wait out spinners and transient state.
    ///
    /// Waiting for a spinner to *disappear* is correct; waiting for the next screen to appear is
    /// usually better still, because it asserts the outcome rather than the absence of a symptom.
    @discardableResult
    static func disappears(
        _ element: XCUIElement,
        timeout: TimeInterval = Wait.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        predicate("exists == false", on: element, timeout: timeout,
                  describedAs: "\(element.debugName) to disappear", file: file, line: line)
    }

    /// Element's label matches an expected value, polled rather than read once.
    ///
    /// The case this exists for: a total that recalculates after a network round trip. Reading
    /// `.label` immediately gets the stale value and the assertion fails intermittently.
    @discardableResult
    static func label(
        _ element: XCUIElement,
        equals expected: String,
        timeout: TimeInterval = Wait.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        predicate("label == %@", arguments: [expected], on: element, timeout: timeout,
                  describedAs: "\(element.debugName) label to equal \"\(expected)\"",
                  file: file, line: line)
    }
}

extension XCUIElement {
    /// A readable name for failure messages. `identifier` when there is one, otherwise the label.
    var debugName: String {
        if !identifier.isEmpty { return "“\(identifier)”" }
        if exists, !label.isEmpty { return "“\(label)”" }
        return "element"
    }
}
