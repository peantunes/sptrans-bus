import XCTest

/// Run in a UI-testing target with the built app installed in the simulator.
final class PlannerUITests: XCTestCase {
    @MainActor
    func testEnabledPlannerLaunchesAndKeepsFormStateConsistent() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.lolados.sp.Sao-Paulo-Onibus")
        app.launchArguments = ["-main_tab_selection", "search", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        let origin = app.textFields["planner.origin"]
        let destination = app.textFields["planner.destination"]
        XCTAssertTrue(origin.waitForExistence(timeout: 30))
        XCTAssertTrue(destination.exists)
        XCTAssertFalse(app.buttons["planner.search"].isEnabled)
        origin.tap()
        origin.typeText("Origem de teste")
        destination.tap()
        destination.typeText("Destino de teste")
        app.buttons["planner.swap"].tap()
        XCTAssertEqual(origin.value as? String, "Destino de teste")
        XCTAssertEqual(destination.value as? String, "Origem de teste")
        XCTAssertFalse(app.buttons["planner.search"].isEnabled, "Unresolved typed text must never reuse coordinates.")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Planner in Portuguese"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
