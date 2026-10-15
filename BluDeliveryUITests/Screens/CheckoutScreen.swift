import XCTest

struct CheckoutScreen: Screen {
    let app: XCUIApplication
    var anchor: XCUIElement { app.navigationBars["Checkout"] }

    private var total: XCUIElement { app.staticTexts[A11y.Checkout.total] }
    private var placeOrderButton: XCUIElement { app.buttons[A11y.Checkout.placeOrder] }
    private var spinner: XCUIElement { app.activityIndicators[A11y.Checkout.spinner] }
    private var confirmation: XCUIElement { app.otherElements[A11y.Checkout.confirmation] }
    private var orderNumber: XCUIElement { app.staticTexts[A11y.Checkout.orderNumber] }

    @discardableResult
    func selectUltra() -> Self {
        tap(app.buttons[A11y.Checkout.deliveryUltra])
        return self
    }

    @discardableResult
    func tip(_ percent: Int) -> Self {
        tap(app.segmentedControls[A11y.Checkout.tipSegment].buttons["\(percent)%"])
        return self
    }

    /// Polls the total until it matches, because it recalculates on every tier and tip change.
    @discardableResult
    func awaitTotal(_ expected: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        Wait.label(total, equals: expected, file: file, line: line)
        return self
    }

    var totalText: String {
        Wait.exists(total)
        return total.label
    }

    @discardableResult
    func placeOrder() -> Self {
        tap(placeOrderButton)
        return self
    }

    /// Waits for the confirmation screen rather than for the spinner to vanish.
    ///
    /// Both would pass today. Only this one still passes if the spinner is removed, and only this
    /// one fails if the order silently doesn't go through — it asserts the outcome, not the
    /// absence of a symptom.
    func awaitConfirmation(file: StaticString = #filePath, line: UInt = #line) -> String {
        Wait.exists(confirmation, timeout: 15, file: file, line: line)
        Wait.exists(orderNumber, file: file, line: line)
        return orderNumber.label
    }

    func errorMessage(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        Wait.exists(app.staticTexts[text], file: file, line: line)
        return app.staticTexts[text].exists
    }

    var isShowingSpinner: Bool { spinner.exists }
}
