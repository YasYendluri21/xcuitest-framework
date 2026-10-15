import XCTest

final class CheckoutFlowTests: BaseTestCase {

    func test_endToEnd_addToCart_checkout_confirms() throws {
        app = AppLauncher().signedIn().launch()

        let products = ProductListScreen(app: app).awaitDisplayed()

        step("add two cases") {
            products.add("SPRING-40").add("SPRING-40").awaitCartCount(2)
        }

        let cart = step("open the cart") { products.openCart() }

        step("subtotal reflects two units") {
            // 2 × $6.49
            XCTAssertEqual(cart.subtotalText, "$12.98")
        }

        let checkout = step("go to checkout") { cart.checkout() }

        step("ULTRA and a 10% tip recalculate the total") {
            // 12.98 subtotal + 5.00 ULTRA fee + 1.30 tip (10% of subtotal)
            checkout.selectUltra().tip(10).awaitTotal("$19.28")
        }

        step("order is confirmed") {
            checkout.placeOrder()
            let orderNumber = checkout.awaitConfirmation()
            XCTAssertTrue(orderNumber.hasPrefix("BLU-"), "got \(orderNumber)")
        }
    }

    func test_deliveryTier_changesTotalByTheFeeDifference() throws {
        app = AppLauncher().withSeededCart().launch()

        let checkout = ProductListScreen(app: app)
            .awaitDisplayed()
            .openCart()
            .checkout()

        // Seeded cart is 2 × SPRING-40 = $12.98. Standard fee $4, ULTRA $5.
        checkout.awaitTotal("$16.98")
        checkout.selectUltra().awaitTotal("$17.98")
    }

    func test_removingLastItem_showsEmptyCart() throws {
        app = AppLauncher().withSeededCart().launch()

        let cart = ProductListScreen(app: app).awaitDisplayed().openCart()
        cart.remove("SPRING-40").remove("SPRING-40")

        XCTAssertTrue(cart.isEmpty, "cart should show its empty state once the last unit is removed")
    }

    func test_declinedPayment_surfacesErrorAndStaysOnCheckout() throws {
        // The failure path is reachable deterministically through a launch flag rather than by
        // hoping a sandbox gateway misbehaves.
        app = AppLauncher().withSeededCart().failingCheckout().launch()

        let checkout = ProductListScreen(app: app).awaitDisplayed().openCart().checkout()
        checkout.placeOrder()

        XCTAssertTrue(checkout.errorMessage("Payment declined. Try a different card."))
        XCTAssertTrue(checkout.isDisplayed, "should remain on checkout so the user can retry")
    }
}
