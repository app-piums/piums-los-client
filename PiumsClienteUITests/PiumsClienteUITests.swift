import XCTest

// MARK: - Auth UI Tests

final class AuthUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING_AUTH"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: Login screen

    func testLoginScreenAppears() {
        XCTAssertTrue(app.staticTexts["Bienvenido de nuevo"].waitForExistence(timeout: 5))
    }

    func testLoginButtonDisabledWhenFieldsEmpty() {
        let loginButton = app.buttons["login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        XCTAssertFalse(loginButton.isEnabled)
    }

    func testLoginButtonDisabledWithOnlyEmail() {
        let emailField = app.textFields["login_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("test@piums.io")

        let loginButton = app.buttons["login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        XCTAssertFalse(loginButton.isEnabled)
    }

    func testLoginButtonEnablesWhenBothFieldsFilled() {
        let emailField = app.textFields["login_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        // \n triggers .onSubmit which moves focus to the password SecureField
        emailField.typeText("test@piums.io\n")

        // SecureField is now focused — type directly
        let passwordField = app.secureTextFields["login_password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.typeText("Password123")

        let loginButton = app.buttons["login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        let enabledPredicate = NSPredicate(format: "enabled == true")
        let enabledExpectation = expectation(for: enabledPredicate, evaluatedWith: loginButton)
        wait(for: [enabledExpectation], timeout: 5.0)
    }

    func testNavigateToRegisterFromLogin() {
        let registerLink = app.buttons["login_register_link"]
        XCTAssertTrue(registerLink.waitForExistence(timeout: 5))
        registerLink.tap()
        XCTAssertTrue(app.staticTexts["Crea tu cuenta"].waitForExistence(timeout: 3))
    }

    func testNavigateToForgotPasswordFromLogin() {
        let forgotButton = app.buttons["login_forgot_password"]
        XCTAssertTrue(forgotButton.waitForExistence(timeout: 5))
        forgotButton.tap()
        XCTAssertTrue(app.staticTexts["Recuperar contraseña"].waitForExistence(timeout: 3))
    }

    func testPasswordToggleShowsTextField() {
        let toggleButton = app.buttons["login_toggle_password"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5))
        // Initially shows SecureField
        XCTAssertTrue(app.secureTextFields["login_password"].exists)
        // Tap toggle
        toggleButton.tap()
        // Now shows TextField
        XCTAssertTrue(app.textFields["login_password"].waitForExistence(timeout: 2))
    }

    // MARK: Register screen

    func testRegisterSubmitDisabledByDefault() {
        app.buttons["login_register_link"].tap()
        let submitButton = app.buttons["register_submit"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertFalse(submitButton.isEnabled)
    }

    func testRegisterSubmitDisabledWithoutTerms() {
        app.buttons["login_register_link"].tap()
        XCTAssertTrue(app.staticTexts["Crea tu cuenta"].waitForExistence(timeout: 5))

        fillRegisterFields()

        let submitButton = app.buttons["register_submit"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        XCTAssertFalse(submitButton.isEnabled)
    }

    func testRegisterSubmitEnablesWithTermsAccepted() {
        app.buttons["login_register_link"].tap()
        XCTAssertTrue(app.staticTexts["Crea tu cuenta"].waitForExistence(timeout: 5))

        fillRegisterFields()

        let termsButton = app.buttons["register_terms"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 3))
        termsButton.tap()

        let submitButton = app.buttons["register_submit"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        let enabledPredicate = NSPredicate(format: "enabled == true")
        let enabledExpectation = expectation(for: enabledPredicate, evaluatedWith: submitButton)
        wait(for: [enabledExpectation], timeout: 5.0)
    }

    func testRegisterBackToLogin() {
        app.buttons["login_register_link"].tap()
        XCTAssertTrue(app.staticTexts["Crea tu cuenta"].waitForExistence(timeout: 3))

        let loginLink = app.buttons["register_login_link"]
        XCTAssertTrue(loginLink.waitForExistence(timeout: 5))
        loginLink.tap()
        XCTAssertTrue(app.staticTexts["Bienvenido de nuevo"].waitForExistence(timeout: 3))
    }

    // MARK: - Helpers

    private func fillRegisterFields() {
        let nameField = app.textFields["register_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        // \n triggers .onSubmit chain: name→email→password→confirm
        nameField.typeText("Test Usuario\n")

        let emailField = app.textFields["register_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        emailField.typeText("test@piums.io\n")

        let passwordField = app.secureTextFields["register_password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.typeText("Password123!\n")

        let confirmField = app.secureTextFields["register_confirm"]
        XCTAssertTrue(confirmField.waitForExistence(timeout: 3))
        confirmField.typeText("Password123!")

        // Dismiss keyboard by tapping the card header area
        if app.staticTexts["Crea tu cuenta"].exists {
            app.staticTexts["Crea tu cuenta"].tap()
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func waitForCondition(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}

// MARK: - Tab Navigation UI Tests

final class TabNavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING_LOGGED_IN", "UI_TESTING_SKIP_TUTORIAL"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testTabBarExists() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testHomeTabIsDefault() {
        let homeTab = app.tabBars.buttons["Inicio"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        XCTAssertTrue(homeTab.isSelected)
    }

    func testNavigateToExploreTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Explorar"].tap()
        // Verify Explorar tab is selected — tab bar button becomes selected
        let exploreTab = tabBar.buttons["Explorar"]
        let selectedPredicate = NSPredicate(format: "isSelected == true")
        let selectedExpectation = expectation(for: selectedPredicate, evaluatedWith: exploreTab)
        wait(for: [selectedExpectation], timeout: 3)
    }

    func testNavigateToMySpaceTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Mi Espacio"].tap()
        let mySpaceTab = tabBar.buttons["Mi Espacio"]
        let selectedPredicate = NSPredicate(format: "isSelected == true")
        let selectedExpectation = expectation(for: selectedPredicate, evaluatedWith: mySpaceTab)
        wait(for: [selectedExpectation], timeout: 3)
    }

    func testNavigateToMessagesTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Mensajes"].tap()
        let messagesTab = tabBar.buttons["Mensajes"]
        let selectedPredicate = NSPredicate(format: "isSelected == true")
        let selectedExpectation = expectation(for: selectedPredicate, evaluatedWith: messagesTab)
        wait(for: [selectedExpectation], timeout: 3)
    }

    func testNavigateToProfileTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Perfil"].tap()
        let profileTab = tabBar.buttons["Perfil"]
        let selectedPredicate = NSPredicate(format: "isSelected == true")
        let selectedExpectation = expectation(for: selectedPredicate, evaluatedWith: profileTab)
        wait(for: [selectedExpectation], timeout: 3)
    }

    func testCanCycleThroughAllTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Verify all 5 tabs exist and are tappable — individual selection tests cover state
        let tabNames = ["Explorar", "Mi Espacio", "Mensajes", "Perfil", "Inicio"]
        for tabName in tabNames {
            let tab = tabBar.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "Tab '\(tabName)' not found")
            XCTAssertTrue(tab.isEnabled, "Tab '\(tabName)' should be enabled")
            tab.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
}

// MARK: - Launch Performance

final class PiumsClienteUITestsLaunchPerformance: XCTestCase {

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
