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
    // MARK: - Opening the other two behind the glass

    /// The panes are built lazily, and the comment where they are built says
    /// why: an app that opened three copies of Instagram at launch would spend
    /// a cold start fetching two pages nobody has asked to see. Still true
    /// about launch, and not true about the ten seconds after it — so the other
    /// two are opened anyway, later. Every check below is one of the ways of
    /// not being the thing that comment warned about.
    private func warming(
        front: Bool = true,
        stopped: Bool = false,
        asked: Set<Pane> = []
    ) -> Warming {
        Warming(theFrontIsUp: front, stopped: stopped, asked: asked)
    }

    private func next(
        _ warming: Warming,
        built: Set<Pane> = [.home],
        me: String? = "marco",
        signedIn: Bool = true
    ) -> Pane? {
        warming.next(built: built, me: me, signedIn: signedIn)
    }

    /// The whole of the original objection, answered with a wait.
    func testNothingIsOpenedUntilThePageInFrontHasFinished() {
        XCTAssertNil(next(warming(front: false)))
        XCTAssertEqual(next(warming(front: true)), .messages)
    }

    /// Messages first, then the profile, then nothing.
    func testTheOtherTwoAreOpenedOneAfterTheOther() {
        XCTAssertEqual(next(warming()), .messages)
        XCTAssertEqual(next(warming(asked: [.messages])), .profile)
        XCTAssertNil(next(warming(asked: [.messages, .profile])))
    }

    /// And never one that is already open — a pane that was tapped before the
    /// waiting was over is a pane that does not want opening again.
    func testAPaneSomebodyOpenedThemselvesIsNotOpenedAgain() {
        XCTAssertEqual(next(warming(), built: [.home, .messages]), .profile)
        XCTAssertNil(next(warming(), built: [.home, .messages, .profile]))
    }

    /// Nothing twice, which is what keeps this from fighting `PaneStack.died`:
    /// a pane iOS took back is dropped rather than rebuilt, and asking for it
    /// again would be rebuilding it by another road.
    func testAPaneTheAppHasGivenUpIsNotAskedForAgain() {
        // Asked for, then lost — so it is no longer built, and still not to be
        // asked for.
        XCTAssertNil(next(warming(asked: [.messages, .profile]), built: [.home]))
    }

    /// A memory warning is not a suggestion.
    func testNothingIsOpenedOnceThePhoneHasAskedForMemoryBack() {
        XCTAssertNil(next(warming(stopped: true)))
        XCTAssertNil(next(warming(stopped: true, asked: [.messages])))
    }

    /// Instagram answers both of those addresses with a login form for
    /// somebody who is not signed in, and fetching two of those is two pages
    /// nobody will ever see.
    func testNothingIsOpenedForSomebodyWhoIsNotSignedIn() {
        XCTAssertNil(next(warming(), me: nil, signedIn: false))
        XCTAssertNil(next(warming(), me: "marco", signedIn: false))
    }

    /// A profile pane has no address until the app knows whose it is, and an
    /// empty one is worse than none: `goToMyProfile` falls back to Instagram's
    /// own entry when there is no name, but it cannot fall back past a pane
    /// that exists and is blank.
    func testAProfileIsNotOpenedUntilThereIsAName() {
        XCTAssertEqual(next(warming(asked: [.messages]), me: nil), nil)
        XCTAssertEqual(next(warming(asked: [.messages]), me: "marco"), .profile)
    }

    /// And the inbox does not wait for one, because it never needed a name.
    func testTheInboxDoesNotWaitForAName() {
        XCTAssertEqual(next(warming(), me: nil), .messages)
    }

    // MARK: - Where a pane starts

    func testEachPaneKnowsItsOwnOpening() {
        XCTAssertEqual(Pane.home.opening(me: "marco", signedIn: false), ContentRules.home)
        XCTAssertEqual(Pane.messages.opening(me: "marco"), ContentRules.messages)
        XCTAssertEqual(
            Pane.profile.opening(me: "marco"),
            ContentRules.profile(forHandle: "marco")
        )
    }

    /// The door a launch knocks on.
    ///
    /// `ContentRules.home` is the login form, and for somebody who is already
    /// signed in it is not a page at all — Instagram answers it with a redirect
    /// to the feed. That is a whole round trip, at the front of a cold start,
    /// on the one screen where somebody is watching a blank, and nothing of it
    /// is ever seen. So the door is chosen from what the last look at the
    /// cookies found.
    ///
    /// Both directions, because the wrong one costs something either way: the
    /// signed-out reader who lands on the feed gets Instagram's own page for a
    /// stranger, whose largest element is a button into Instagram's app.
    func testTheHomePaneOpensOnTheFeedForSomebodyWhoIsSignedIn() {
        XCTAssertEqual(Pane.home.opening(me: "marco", signedIn: true), ContentRules.feed)
        XCTAssertEqual(Pane.home.opening(me: nil, signedIn: true), ContentRules.feed)
        XCTAssertEqual(Pane.home.opening(me: nil, signedIn: false), ContentRules.home)
    }

    /// And the other two are the same address whoever is signed in. The inbox
    /// and a profile are addresses of their own; neither is a door to be
    /// chosen.
    func testTheOtherTwoPanesDoNotCareWhoIsSignedIn() {
        XCTAssertEqual(
            Pane.messages.opening(me: "marco", signedIn: true),
            Pane.messages.opening(me: "marco", signedIn: false)
        )
        XCTAssertEqual(
            Pane.profile.opening(me: "marco", signedIn: true),
            Pane.profile.opening(me: "marco", signedIn: false)
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
        XCTAssertNotNil(Pane.home.opening(me: nil, signedIn: false), "the feed never needed a name")
        XCTAssertNotNil(Pane.home.opening(me: nil, signedIn: true))
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
