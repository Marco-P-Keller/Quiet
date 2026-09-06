import XCTest
@testable import Quiet

/// Instagram lets somebody change accounts without loading anything, and the
/// two panes off the glass keep the last person's pages. Noticing that is one
/// cookie and two rules, and both rules are the kind that look like a detail.
final class WhoIsSignedInTests: XCTestCase {
    func testTheSameAccountIsNothing() {
        XCTAssertEqual(AccountChange.of(was: "42", now: "42"), .nothing)
    }

    func testNobodyToNobodyIsNothing() {
        XCTAssertEqual(AccountChange.of(was: nil, now: nil), .nothing)
    }

    func testNobodyToSomebodyIsASignIn() {
        XCTAssertEqual(AccountChange.of(was: nil, now: "42"), .signedIn)
    }

    func testSomebodyToNobodyIsASignOut() {
        XCTAssertEqual(AccountChange.of(was: "42", now: nil), .signedOut)
    }

    func testSomebodyElseIsASwitch() {
        XCTAssertEqual(AccountChange.of(was: "42", now: "43"), .switched)
    }

    /// The one this exists for.
    func testOnlyASwitchIsActedOn() {
        XCTAssertTrue(AccountChange.acts(on: .switched, hasLooked: true))
        XCTAssertFalse(AccountChange.acts(on: .signedIn, hasLooked: true))
        XCTAssertFalse(AccountChange.acts(on: .signedOut, hasLooked: true))
        XCTAssertFalse(AccountChange.acts(on: .nothing, hasLooked: true))
    }

    /// At launch nobody has changed accounts; the app has merely started. A
    /// first reading acted on would tear every pane down on the way up.
    func testTheFirstReadingIsNeverActedOn() {
        for change in [AccountChange.switched, .signedIn, .signedOut, .nothing] {
            XCTAssertFalse(AccountChange.acts(on: change, hasLooked: false))
        }
    }

    /// A switch is a burst of cookie writes with a moment in the middle that
    /// has no account at all. The watcher waits for the burst to end, and this
    /// is the reading it would have taken if it did not: a sign-out and a
    /// sign-in, one after the other, each of which would restart the app.
    func testTheMomentInTheMiddleOfASwitchIsTwoEvents() {
        XCTAssertEqual(AccountChange.of(was: "42", now: nil), .signedOut)
        XCTAssertEqual(AccountChange.of(was: nil, now: "43"), .signedIn)
        // Which is why neither is acted on, and only the settled reading is.
        XCTAssertFalse(AccountChange.acts(on: .signedOut, hasLooked: true))
        XCTAssertFalse(AccountChange.acts(on: .signedIn, hasLooked: true))
        XCTAssertTrue(AccountChange.acts(on: .of(was: "42", now: "43"), hasLooked: true))
    }

    // MARK: - The one bit the next launch reads

    /// Which door the app knocks on is decided before anything can be asked,
    /// so it is decided from the last answer. Three states matter and the first
    /// is the one that would be got wrong: nobody has ever looked.
    func testWhatTheLastLookFoundOutlivesTheLaunch() {
        let name = "quiet.tests.thelastlook"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertFalse(
            TheLastLook.foundSomebody(in: defaults),
            "a first launch has no session, and the login form is where it belongs"
        )

        TheLastLook.found(somebody: true, in: defaults)
        XCTAssertTrue(TheLastLook.foundSomebody(in: defaults))

        // Signing out has to reach this, or the next launch opens on the feed
        // for somebody who has just left it.
        TheLastLook.found(somebody: false, in: defaults)
        XCTAssertFalse(TheLastLook.foundSomebody(in: defaults))
    }
}
