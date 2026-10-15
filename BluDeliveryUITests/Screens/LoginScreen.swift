import XCTest

struct LoginScreen: Screen {
    let app: XCUIApplication
    var anchor: XCUIElement { app.textFields[A11y.Login.email] }

    private var emailField: XCUIElement { app.textFields[A11y.Login.email] }
    private var passwordField: XCUIElement { app.secureTextFields[A11y.Login.password] }
    private var submitButton: XCUIElement { app.buttons[A11y.Login.submit] }
    private var errorText: XCUIElement { app.staticTexts[A11y.Login.error] }

    @discardableResult
    func signIn(email: String, password: String) -> Self {
        type(email, into: emailField)
        type(password, into: passwordField)
        tap(submitButton)
        return self
    }

    /// Waits for the error to appear and returns it, rather than reading it immediately — the
    /// message arrives after an async call, so reading straight after the tap races it.
    func errorMessage(file: StaticString = #filePath, line: UInt = #line) -> String {
        Wait.exists(errorText, file: file, line: line)
        return errorText.label
    }

    var isShowingError: Bool { errorText.exists }
}
