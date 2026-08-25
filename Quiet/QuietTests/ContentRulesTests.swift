import XCTest
@testable import Quiet

final class ContentRulesTests: XCTestCase {
    private func routing(_ address: String) -> Routing {
        ContentRules.routing(for: URL(string: address)!)
    }

    func testTheFeedAndTheThingsYouWentLookingForAreAllowed() {
        for address in [
            "https://www.instagram.com/",
            "https://www.instagram.com/direct/inbox/",
            "https://www.instagram.com/p/CxYz123/",
            "https://www.instagram.com/stories/someone/123/",
            "https://www.instagram.com/someone/",
            "https://www.instagram.com/someone/tagged/",
            "https://www.instagram.com/accounts/login/",
            "https://www.instagram.com/accounts/edit/",
            "https://i.instagram.com/api/v1/whatever",
        ] {
            XCTAssertEqual(routing(address), .allow, address)
        }
    }

    func testReelsAreRefusedWhereverTheyAppear() {
        for address in [
            "https://www.instagram.com/reels/",
            "https://www.instagram.com/reels/audio/123/",
            "https://www.instagram.com/reel/CxYz123/",
            "https://www.instagram.com/someone/reels/",
            // IGTV's old address. Instagram kept it alive as a redirect into
            // the video player, so a link written years ago is still a door.
            "https://www.instagram.com/tv/CxYz123/",
            "https://www.instagram.com/tv/",
        ] {
            XCTAssertEqual(routing(address), .refuse(.reels), address)
        }
    }

    /// The same guard as for `reels`: whole components, never a prefix, or
    /// every account whose name starts with those two letters disappears.
    func testAccountsThatMerelyBeginWithTVAreFine() {
        for address in [
            "https://www.instagram.com/tvtotal/",
            "https://www.instagram.com/tv_show/",
        ] {
            XCTAssertEqual(routing(address), .allow, address)
        }
    }

    func testExploreAndTheDirectoriesBehindItAreRefused() {
        for address in [
            "https://www.instagram.com/explore/",
            "https://www.instagram.com/explore/tags/sunset/",
            "https://www.instagram.com/explore/search/keyword/?q=x",
            "https://www.instagram.com/directory/profiles/",
            "https://www.instagram.com/accounts/suggested/",
        ] {
            XCTAssertEqual(routing(address), .refuse(.explore), address)
        }
    }

    /// The bug this guards against: a prefix match on "/reels" would also swallow
    /// every profile whose name starts with those letters.
    func testProfilesThatMerelyLookLikeBlockedPathsAreFine() {
        for address in [
            "https://www.instagram.com/reelstuff/",
            "https://www.instagram.com/explorers/",
            "https://www.instagram.com/reeling/",
            "https://www.instagram.com/directorycorp/",
        ] {
            XCTAssertEqual(routing(address), .allow, address)
        }
    }

    func testCaseAndTrailingSlashesDoNotMatter() {
        XCTAssertEqual(routing("https://WWW.INSTAGRAM.COM/Reels"), .refuse(.reels))
        XCTAssertEqual(routing("https://www.instagram.com/REEL/abc"), .refuse(.reels))
    }

    func testTheRestOfTheWebIsHandedToTheSystem() {
        for address in [
            "https://example.com/",
            "https://threads.net/@someone",
            "mailto:hello@example.com",
            "tel:+41000000000",
            "itms-apps://apps.apple.com/app/id1",
        ] {
            XCTAssertEqual(routing(address), .openOutside, address)
        }
    }

    /// iOS opens any app a page names, without asking anyone, so a page could
    /// reach for an app on the phone that nobody reached for. Only the handful
    /// of schemes a person actually taps in a document leave this app.
    func testSchemesNobodyTapsGoNowhere() {
        for address in [
            "fb://profile/1",
            "whatsapp://send?text=hi",
            "shortcuts://run-shortcut?name=x",
            "tg://resolve?domain=x",
            "prefs:root=General",
        ] {
            XCTAssertEqual(routing(address), .ignore, address)
        }
    }

    /// Signing in to Instagram legitimately passes through Meta's own domains.
    /// Bouncing those to Safari would break logging in.
    func testMetaLoginDomainsStayInside() {
        XCTAssertEqual(routing("https://www.facebook.com/dialog/oauth?x=1"), .allow)
        XCTAssertEqual(routing("https://accountscenter.instagram.com/"), .allow)
    }

    /// Seen on the running app: Instagram's own logged-out page offers an
    /// "Open Instagram" button. Handing that to the system would undo the whole
    /// app in one tap.
    func testInstagramsOwnAppIsRefused() {
        XCTAssertEqual(routing("instagram://app"), .refuse(.theApp))
        XCTAssertEqual(routing("instagram://media?id=1"), .refuse(.theApp))
        XCTAssertEqual(routing("instagram-stories://share"), .refuse(.theApp))
    }

    func testWebKitInternalsAreLeftAlone() {
        XCTAssertEqual(routing("about:blank"), .allow)
    }

    func testFindSomeoneAcceptsWhatPeopleActuallyType() {
        let expected = URL(string: "https://www.instagram.com/someone.here_1/")
        for typed in [
            "someone.here_1",
            "  someone.here_1 ",
            "@someone.here_1",
            "SomeOne.Here_1",
            "https://www.instagram.com/someone.here_1/",
            "instagram.com/someone.here_1",
        ] {
            XCTAssertEqual(ContentRules.profile(forHandle: typed), expected, typed)
        }
    }

    func testFindSomeoneRefusesThingsThatAreNotUsernames() {
        for typed in ["", "   ", "@", "two words", "someone/../else", String(repeating: "a", count: 31)] {
            XCTAssertNil(ContentRules.profile(forHandle: typed), typed)
        }
    }

    // MARK: - The screens that own the bottom edge

    /// Two things read this: the row along the bottom stays off these screens,
    /// and the pull that reloads the page is not offered on them.
    func testAStoryAndAnOpenConversationOwnTheWholeScreen() {
        for address in [
            "https://www.instagram.com/stories/someone/123/",
            "https://www.instagram.com/direct/t/17845/",
            "https://www.instagram.com/direct/new/",
            // Without the trailing slash, because `URL.path` takes one off and
            // a rule written in prefixes is exactly where that goes unnoticed.
            "https://www.instagram.com/direct/new",
            "https://www.instagram.com/direct/t/17845"
        ] {
            XCTAssertTrue(
                ContentRules.isImmersive(URL(string: address)),
                "\(address) puts something of its own along the bottom edge"
            )
        }
    }

    /// The inbox is a list, not a conversation. The row belongs on it, and so
    /// does the pull — this is the boundary the two paths share a prefix at.
    func testEverywhereElseIsAnOrdinaryPage() {
        for address in [
            "https://www.instagram.com/",
            "https://www.instagram.com/direct/inbox/",
            "https://www.instagram.com/someone/",
            "https://www.instagram.com/p/abc123/"
        ] {
            XCTAssertFalse(
                ContentRules.isImmersive(URL(string: address)),
                "\(address) is a page like any other"
            )
        }
    }

    /// Nothing loaded yet is not a story.
    func testNoAddressIsAnOrdinaryPage() {
        XCTAssertFalse(ContentRules.isImmersive(nil))
    }

    // MARK: - Signing in

    /// Not a rule about what opens. A rule about what gets explained: the one
    /// failure that makes the app useless on first run is a login handed to
    /// Safari halfway through, and it used to happen in silence.
    func testTheSignInFlowIsRecognised() {
        for address in [
            "https://www.instagram.com/accounts/login/",
            "https://www.instagram.com/accounts/login/two_factor?next=%2F",
            "https://www.instagram.com/accounts/signup/email/",
            "https://www.instagram.com/accounts/password/reset/",
            "https://www.instagram.com/accounts/onetap/",
            "https://www.instagram.com/challenge/AbC/123/",
            "https://www.facebook.com/login.php",
            "https://m.facebook.com/v1/dialog/oauth",
            "https://accountscenter.instagram.com/password_and_security/",
        ] {
            XCTAssertTrue(
                ContentRules.isSignInFlow(URL(string: address)!),
                address
            )
        }
    }

    /// Reading a feed is not signing in, and a notice about Safari arriving
    /// while somebody scrolls would be the app talking for no reason.
    func testOrdinaryInstagramPagesAreNotTheSignInFlow() {
        for address in [
            "https://www.instagram.com/",
            "https://www.instagram.com/someone/",
            "https://www.instagram.com/direct/inbox/",
            "https://www.instagram.com/accounts/edit/",
            "https://example.com/anything",
        ] {
            XCTAssertFalse(
                ContentRules.isSignInFlow(URL(string: address)!),
                address
            )
        }
        XCTAssertFalse(ContentRules.isSignInFlow(nil))
    }

}
