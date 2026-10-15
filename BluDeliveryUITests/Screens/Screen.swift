import XCTest

/// Base for every page object.
///
/// Two rules this layer enforces. A screen exposes *actions and queries*, never raw `XCUIElement`s
/// — a test that reaches into `screen.app.buttons[...]` has defeated the point. And every action
/// waits for the element to be hittable before touching it, so synchronization lives here rather
/// than being re-remembered in each test.
protocol Screen {
    var app: XCUIApplication { get }
    /// The element whose presence means this screen is on display.
    var anchor: XCUIElement { get }
}

extension Screen {
    /// Blocks until the screen is actually up. Returning Self keeps call sites chainable.
    @discardableResult
    func awaitDisplayed(file: StaticString = #filePath, line: UInt = #line) -> Self {
        Wait.exists(anchor, file: file, line: line)
        return self
    }

    var isDisplayed: Bool { anchor.exists }

    /// Tap that waits for hittability first. Every tap in the suite goes through here.
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        Wait.hittable(element, file: file, line: line)
        element.tap()
    }

    /// Type into a field, clearing it first.
    ///
    /// `typeText` appends, so a field with existing content silently concatenates. Selecting all
    /// and replacing is the only reliable way to set a known value.
    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        Wait.hittable(field, file: file, line: line)
        field.tap()

        if let existing = field.value as? String, !existing.isEmpty, existing != field.placeholderValue {
            field.press(forDuration: 1.0)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) {
                app.menuItems["Select All"].tap()
            }
        }

        field.typeText(text)
    }
}
