import XCTest

final class ShutterDropUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Past onboarding, the app opens on its three tabs.
    @MainActor
    func testLaunchShowsTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboardingDone", "YES", "-sampleData"]
        app.launch()

        for tab in ["Queue", "Posted", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5), "No \(tab) tab")
        }
    }
}
