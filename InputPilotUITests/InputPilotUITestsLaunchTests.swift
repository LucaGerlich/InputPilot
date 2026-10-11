import XCTest

final class InputPilotUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Regression test for 1.0.0, where a new user got no window at all and so
    /// no way to grant Input Monitoring. With onboarding not yet completed the
    /// welcome window must open by itself - whether or not this build already
    /// has the permission (CI's ad-hoc build never does).
    @MainActor
    func testWelcomeWindowOpensOnFirstLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboardingCompleted", "NO"]
        app.launch()

        XCTAssertTrue(app.windows["Welcome to InputPilot"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Welcome window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
