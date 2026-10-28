import XCTest

/// Adds a report, sees it on Home, and deletes it (spec 14.4).
@MainActor
final class ReportLifecycleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAddSeeAndDeleteReport() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.buttons["Add"].tap()
        app.buttons["Add report"].tap()
        let name = app.textFields["Report name"]
        name.tap(); name.typeText("Blood pressure report")
        app.buttons["Save"].tap()
        let card = app.staticTexts["Blood pressure report"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        app.buttons["Delete report"].tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Blood pressure report"].waitForExistence(timeout: 2))
    }
}
