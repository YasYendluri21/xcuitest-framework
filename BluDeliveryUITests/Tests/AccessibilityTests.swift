import XCTest

/// Accessibility coverage beyond functional correctness.
///
/// A preferred qualification on plenty of Apple-platform roles, and cheap to assert once the app
/// is identifier-driven: if an element is reachable by a test, most of the work for VoiceOver is
/// already done. These check the parts that identifiers alone don't guarantee.
final class AccessibilityTests: BaseTestCase {

    func test_everyInteractiveElement_hasAnAccessibleLabel() throws {
        app = AppLauncher().signedIn().launch()
        ProductListScreen(app: app).awaitDisplayed()

        let unlabelled = app.buttons.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .filter { $0.label.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertTrue(
            unlabelled.isEmpty,
            "\(unlabelled.count) interactive element(s) have no accessible label — VoiceOver would announce them as “button”"
        )
    }

    func test_checkoutTotal_isExposedAsText_notOnlyVisually() throws {
        app = AppLauncher().withSeededCart().launch()

        let checkout = ProductListScreen(app: app).awaitDisplayed().openCart().checkout()

        // The total must be a real string in the accessibility tree. If it were drawn into an
        // image or a custom canvas, this fails — and a screen reader user could not hear the
        // amount they are about to be charged.
        XCTAssertFalse(checkout.totalText.isEmpty)
        XCTAssertTrue(checkout.totalText.contains("$"))
    }

    func test_deliveryTier_reportsSelectionState() throws {
        app = AppLauncher().withSeededCart().launch()

        let checkout = ProductListScreen(app: app).awaitDisplayed().openCart().checkout()
        checkout.selectUltra()

        // Selection communicated by colour alone fails WCAG 1.4.1 and is invisible to VoiceOver.
        // The trait is what makes it perceivable.
        let ultra = app.buttons[A11y.Checkout.deliveryUltra]
        Wait.exists(ultra)
        XCTAssertTrue(ultra.isSelected, "selected tier should carry the isSelected trait")
    }
}
