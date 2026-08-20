import XCTest

/// Whether the app can be used without seeing it.
///
/// Quiet has one hidden gesture — a long press on the status bar — and a hidden
/// gesture is invisible to VoiceOver, which would leave the panel unreachable
/// for anyone who cannot perform it. There is an accessibility element in its
/// place for exactly that reason, and until now nothing checked that it was
/// still there, still a button, and still opened the panel.
///
/// These tests walk the same path a person using VoiceOver walks: they never
/// swipe, drag, or long-press anything. They find elements by the name they are
/// announced under, and activate them. If a screen can be driven this way it
/// can be driven by voice; if it cannot, this goes red.
///
/// Each test starts the app in a named state through the debug-only rehearsal
/// argument, so the curtain — otherwise five minutes of waiting away — is a
/// launch rather than a wait.
final class SpeaksAloudTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ scene: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-QuietRehearsal", scene]
        app.launch()
        return app
    }

    /// The first screen: two sentences and one thing to press, both announced.
    func testTheOpeningQuestionCanBeHeardAndAnswered() {
        let app = launch("fresh")

        let opening = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "minus the parts")
        ).firstMatch
        XCTAssertTrue(opening.waitForExistence(timeout: 20), "The opening line must be readable aloud")

        let carryOn = app.buttons["Continue"]
        XCTAssertTrue(carryOn.exists, "The way on must be a button")
        carryOn.tap()

        let commit = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Set ")
        ).firstMatch
        XCTAssertTrue(commit.waitForExistence(timeout: 10), "The second screen must offer a labelled button")
        XCTAssertFalse(commit.label.isEmpty)
    }

    /// The way into the panel has to be a real thing, not only a gesture.
    ///
    /// It used to be a press on the status bar and nothing else, with an
    /// accessibility element standing in for it — findable by VoiceOver and by
    /// nobody's eye. The mark in the bottom corner is a plain button, which is
    /// what makes this test able to do what a person does: find it by name, tap
    /// it, and get the panel.
    func testThePanelIsReachableWithoutTheGesture() {
        let app = launch("browsing")

        let wayIn = app.buttons["Quiet settings"]
        XCTAssertTrue(
            wayIn.waitForExistence(timeout: 30),
            "The way into Quiet's own settings must exist as a button"
        )
        XCTAssertEqual(wayIn.label, "Quiet settings", "and be announced by name")
        wayIn.tap()

        XCTAssertTrue(
            app.buttons["Done"].waitForExistence(timeout: 10),
            "Tapping it must open the panel"
        )
    }

    /// Everything the panel offers, found by name.
    func testThePanelSaysWhatEachRowIs() {
        let app = launch("panel")

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 30))

        // The row announces itself with its value: "Daily limit, 20 minutes".
        let limitRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Daily limit")
        ).firstMatch
        XCTAssertTrue(limitRow.exists, "The row that changes the limit must be a named button")

        let today = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "left today")
        ).firstMatch
        XCTAssertTrue(today.exists, "How much of today is left must be readable")

        limitRow.tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(
            wheel.waitForExistence(timeout: 10),
            "The limit is chosen on a wheel, which VoiceOver adjusts"
        )
        XCTAssertNotNil(wheel.value, "The wheel must announce its current value")
    }

    /// The end of the day: what happened, when it comes back, and one way out.
    func testTheCurtainExplainsItselfAndHasADoor() {
        let app = launch("spent")

        let headline = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "for today")
        ).firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 30), "The curtain must say what has happened")

        let explanation = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "opens again at")
        ).firstMatch
        XCTAssertTrue(explanation.exists, "It must say when the day comes back")

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.exists, "The one door out must be a button")
        settings.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10), "And it must open the panel")
    }
}
