import XCTest

final class DebugAccessibilityTest: XCTestCase {

    func testPrintTabBarElements() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING_LOGGED_IN"]
        app.launch()

        _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 2)

        var lines: [String] = ["=== TAB BAR BUTTONS ==="]
        let tabBar = app.tabBars.firstMatch
        for i in 0..<tabBar.buttons.count {
            let btn = tabBar.buttons.element(boundBy: i)
            lines.append("  [\(i)] label='\(btn.label)' id='\(btn.identifier)' selected=\(btn.isSelected)")
        }

        lines.append("\n=== ALL NAVIGATION BARS ===")
        for i in 0..<app.navigationBars.count {
            let nb = app.navigationBars.element(boundBy: i)
            lines.append("  [\(i)] label='\(nb.label)' id='\(nb.identifier)'")
        }

        lines.append("\n=== TAP Explorar (index 1) ===")
        tabBar.buttons.element(boundBy: 1).tap()
        Thread.sleep(forTimeInterval: 2)

        lines.append("\n=== NAV BARS AFTER TAP ===")
        for i in 0..<app.navigationBars.count {
            let nb = app.navigationBars.element(boundBy: i)
            lines.append("  [\(i)] label='\(nb.label)' id='\(nb.identifier)'")
        }
        lines.append("\n=== STATIC TEXTS AFTER TAP (first 15) ===")
        for i in 0..<min(15, app.staticTexts.count) {
            let st = app.staticTexts.element(boundBy: i)
            lines.append("  [\(i)] label='\(st.label)' id='\(st.identifier)'")
        }

        try lines.joined(separator: "\n").write(toFile: "/tmp/piums_tab_debug.txt", atomically: true, encoding: .utf8)
        XCTAssertTrue(true) // always pass
    }

    func testPrintLoginElements() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING_AUTH"]
        app.launch()

        _ = app.staticTexts["Bienvenido de nuevo"].waitForExistence(timeout: 10)

        var lines: [String] = ["\n=== TEXT FIELDS ==="]
        for i in 0..<app.textFields.count {
            let f = app.textFields.element(boundBy: i)
            lines.append("  [\(i)] id='\(f.identifier)' placeholder='\(f.placeholderValue ?? "nil")'")
        }
        lines.append("\n=== SECURE TEXT FIELDS ===")
        for i in 0..<app.secureTextFields.count {
            let f = app.secureTextFields.element(boundBy: i)
            lines.append("  [\(i)] id='\(f.identifier)' placeholder='\(f.placeholderValue ?? "nil")'")
        }
        lines.append("\n=== BUTTONS ===")
        for i in 0..<min(12, app.buttons.count) {
            let b = app.buttons.element(boundBy: i)
            lines.append("  [\(i)] label='\(b.label)' id='\(b.identifier)' enabled=\(b.isEnabled)")
        }

        try lines.joined(separator: "\n").write(toFile: "/tmp/piums_login_debug.txt", atomically: true, encoding: .utf8)
        XCTAssertTrue(true)
    }
}
