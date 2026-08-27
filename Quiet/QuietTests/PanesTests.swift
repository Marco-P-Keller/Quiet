import XCTest
@testable import Quiet

/// The three pages the app keeps open, and the two facts about them that can go
/// wrong without anybody noticing.
///
/// Neither is testable through a web view — a pane is a `WKWebView` and this
/// bundle has no glass to put one on. Both are testable *underneath* it, which
/// is where they actually live: where a pane starts, and which drawer each
/// pane's place is kept in.
final class PanesTests: XCTestCase {
    // MARK: - Where a pane starts

    func testEachPaneKnowsItsOwnOpening() {
        XCTAssertEqual(Pane.home.opening(me: "marco"), ContentRules.home)
        XCTAssertEqual(Pane.messages.opening(me: "marco"), ContentRules.messages)
        XCTAssertEqual(
            Pane.profile.opening(me: "marco"),
            ContentRules.profile(forHandle: "marco")
        )
    }

    /// The one pane that cannot be opened cold.
    ///
    /// A profile pane needs a name, and on a first launch the app does not have
    /// one for the second or so before Instagram's own page answers. Nothing
    /// rather than a guess: an opening address invented here would be a
    /// stranger's profile behind a button marked "your profile", which is a
    /// mistake this project has already made once by deducing the name instead
    /// of asking for it.
    func testTheProfileHasNoAddressUntilThereIsAName() {
        XCTAssertNil(Pane.profile.opening(me: nil))
        XCTAssertNotNil(Pane.home.opening(me: nil), "the feed never needed a name")
        XCTAssertNotNil(Pane.messages.opening(me: nil))
    }

    /// A handle Instagram would not accept is not an address either. The rule
    /// itself is `ContentRules`'; this is the pane asking rather than guessing.
    func testAHandleThatIsNotOneOpensNothing() {
        XCTAssertNil(Pane.profile.opening(me: ""))
        XCTAssertNil(Pane.profile.opening(me: "not a handle"))
    }

    // MARK: - Which drawer each place is kept in

    /// The compatibility promise, said out loud.
    ///
    /// The home pane keeps the keys the app has always used. A version of this
    /// that keyed all three afresh would have cost every reader already on the
    /// store the place they were standing in when they updated — small, once,
    /// and free to avoid, which is the only reason not to.
    func testTheHomePaneKeepsTheKeysItAlwaysHad() {
        XCTAssertEqual(ThePlace.key(ThePlace.state, .home), "quiet.place")
        XCTAssertEqual(ThePlace.key(ThePlace.when, .home), "quiet.place.at")
        XCTAssertEqual(ThePlace.key(ThePlace.address, .home), "quiet.place.address")
    }

    /// And no two panes ever share one.
    ///
    /// Which is the failure this is really for: a suffix dropped from one of
    /// the three would put the inbox back into the feed's slot, and what that
    /// looks like on a phone is the app opening on the wrong page once in a
    /// while — the kind of thing that gets reported as "it feels random".
    func testNoTwoPanesShareADrawer() {
        for base in [ThePlace.state, ThePlace.when, ThePlace.address] {
            let keys = Pane.allCases.map { ThePlace.key(base, $0) }
            XCTAssertEqual(Set(keys).count, Pane.allCases.count, "\(base) collides")
        }
    }

    func testForgettingEverythingLeavesNothingBehind() {
        let defaults = UserDefaults(suiteName: "quiet.panes.tests")!
        defer { defaults.removePersistentDomain(forName: "quiet.panes.tests") }

        for pane in Pane.allCases {
            defaults.set(Data([1]), forKey: ThePlace.key(ThePlace.state, pane))
            defaults.set(Date().timeIntervalSince1970, forKey: ThePlace.key(ThePlace.when, pane))
            defaults.set("https://www.instagram.com/", forKey: ThePlace.key(ThePlace.address, pane))
        }

        ThePlace.forgetEverything(in: defaults)

        for pane in Pane.allCases {
            XCTAssertNil(defaults.data(forKey: ThePlace.key(ThePlace.state, pane)), "\(pane)")
            XCTAssertEqual(defaults.double(forKey: ThePlace.key(ThePlace.when, pane)), 0, "\(pane)")
            XCTAssertNil(defaults.string(forKey: ThePlace.key(ThePlace.address, pane)), "\(pane)")
        }
    }

    /// Signing out reaches all three; leaving one pane reaches only that one.
    func testForgettingOnePaneLeavesTheOthersStanding() {
        let defaults = UserDefaults(suiteName: "quiet.panes.tests.one")!
        defer { defaults.removePersistentDomain(forName: "quiet.panes.tests.one") }

        for pane in Pane.allCases {
            defaults.set(Data([1]), forKey: ThePlace.key(ThePlace.state, pane))
        }

        ThePlace.forget(.profile, in: defaults)

        XCTAssertNil(defaults.data(forKey: ThePlace.key(ThePlace.state, .profile)))
        XCTAssertNotNil(defaults.data(forKey: ThePlace.key(ThePlace.state, .home)))
        XCTAssertNotNil(defaults.data(forKey: ThePlace.key(ThePlace.state, .messages)))
    }
}
