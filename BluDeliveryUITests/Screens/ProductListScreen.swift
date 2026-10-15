import XCTest

struct ProductListScreen: Screen {
    let app: XCUIApplication
    var anchor: XCUIElement { app.collectionViews[A11y.Products.list].firstMatch }

    private var cartButton: XCUIElement { app.buttons[A11y.Products.cartButton] }
    private var cartBadge: XCUIElement { app.staticTexts[A11y.Products.cartBadge] }

    @discardableResult
    func add(_ sku: String) -> Self {
        tap(app.buttons[A11y.Products.addButton(sku)])
        return self
    }

    /// Reads the cart count, polling until the badge reflects an expected value.
    ///
    /// Asserting on the badge straight after a tap is the classic race in this suite — SwiftUI
    /// re-renders asynchronously, so the first read often catches the previous value.
    @discardableResult
    func awaitCartCount(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) -> Self {
        Wait.label(cartBadge, equals: "\(expected)", file: file, line: line)
        return self
    }

    func openCart() -> CartScreen {
        tap(cartButton)
        return CartScreen(app: app).awaitDisplayed()
    }
}
