import XCTest

/// The one test that touches the real thing.
///
/// Everything else in this project runs against pure logic: the rules, the
/// clock, the ledger. None of it says whether the app that a person actually
/// holds gets as far as Instagram. This does — it starts with an empty install,
/// answers the one question setup asks, and waits for the web view to arrive.
///
/// It also leaves the app past setup, which is what lets the workflow
/// photograph the feed afterwards rather than the onboarding screen.
final class ReachesInstagramTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSetupLeadsToInstagram() {
        let app = XCUIApplication()
        app.launch()

        let carryOn = app.buttons["Continue"]
        XCTAssertTrue(
            carryOn.waitForExistence(timeout: 20),
            "Setup should open on the screen that says what the app is"
        )
        carryOn.tap()

        // "Set 20 minutes a day" — matched by its shape rather than its number,
        // so changing the default choice does not break the test.
        let commit = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set ")
        ).firstMatch
        XCTAssertTrue(
            commit.waitForExistence(timeout: 10),
            "The second screen should offer to set a daily limit"
        )
        commit.tap()

        // Instagram's mobile site, over a network, on a machine in a data
        // centre. Generous, because none of that is fast.
        let web = app.webViews.firstMatch
        XCTAssertTrue(
            web.waitForExistence(timeout: 60),
            "Setup should hand over to the web view"
        )

        // Give the page time to paint before the workflow photographs it.
        Thread.sleep(forTimeInterval: 12)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "instagram-in-quiet"
        shot.lifetime = .keepAlways
        add(shot)

        // The whole promise, checked: close the app, open it again, and the
        // answer given during setup should still be the answer. If setup comes
        // back, nothing the app is told is being kept — and a limit that does
        // not survive closing the app is not a limit.
        app.terminate()
        app.launch()
        XCTAssertFalse(
            app.buttons["Continue"].waitForExistence(timeout: 10),
            "Setup came back after a relaunch, so nothing is being stored"
        )
    }
}
