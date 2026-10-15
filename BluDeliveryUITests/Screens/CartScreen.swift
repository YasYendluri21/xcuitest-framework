import XCTest

struct CartScreen: Screen {
    let app: XCUIApplication
    var anchor: XCUIElement { app.navigationBars["Cart"] }

    private var subtotal: XCUIElement { app.staticTexts[A11y.Cart.subtotal] }
    private var checkoutButton: XCUIElement { app.buttons[A11y.Cart.checkout] }
    private var emptyState: XCUIElement { app.staticTexts["Your cart is empty"] }

    var subtotalText: String {
        Wait.exists(subtotal)
        return subtotal.label
    }

    var isEmpty: Bool { emptyState.exists }

    @discardableResult
    func remove(_ sku: String) -> Self {
        tap(app.buttons[A11y.Cart.removeButton(sku)])
        return self
    }

    func checkout() -> CheckoutScreen {
        tap(checkoutButton)
        return CheckoutScreen(app: app).awaitDisplayed()
    }
}
