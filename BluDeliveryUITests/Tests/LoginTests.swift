import XCTest

final class LoginTests: BaseTestCase {
    private var login: LoginScreen { LoginScreen(app: app) }

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = AppLauncher().launch()
    }

    func test_signInWithValidCredentials_showsProductList() throws {
        step("sign in") {
            login.awaitDisplayed().signIn(email: "priya@example.com", password: "correct-horse")
        }

        step("lands on the product list") {
            XCTAssertTrue(ProductListScreen(app: app).awaitDisplayed().isDisplayed)
        }
    }

    func test_signInWithMalformedEmail_showsValidationError() throws {
        login.awaitDisplayed().signIn(email: "not-an-email", password: "correct-horse")

        XCTAssertEqual(login.errorMessage(), "Enter a valid email address")
        // The negative half matters as much as the positive one: we must not have navigated.
        XCTAssertFalse(ProductListScreen(app: app).isDisplayed, "should remain on the login screen")
    }

    func test_signInWithShortPassword_showsGenericError() throws {
        login.awaitDisplayed().signIn(email: "priya@example.com", password: "short")

        // Deliberately generic — an error that distinguishes "wrong password" from "no such user"
        // is a user-enumeration leak.
        XCTAssertEqual(login.errorMessage(), "Invalid email or password")
    }

    func test_signInButton_isDisabledWhileAuthenticating() throws {
        login.awaitDisplayed().signIn(email: "priya@example.com", password: "correct-horse")

        // Guards against double submission. The window is short, so this is the one assertion in
        // the suite that races by nature — hence a predicate wait rather than an immediate read.
        let button = app.buttons[A11y.Login.submit]
        Wait.predicate("isEnabled == false", on: button, timeout: 3,
                       describedAs: "sign-in button to disable during the request")
    }
}
