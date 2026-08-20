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
        ] {
            XCTAssertEqual(routing(address), .refuse(.reels), address)
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

    /// The app draws a header on Instagram's pages and must not draw one on the
    /// page a person signs in on, which has a wordmark of its own in the middle
    /// of it. Both halves matter: a profile called "login" is not a login page.
    func testSignInPagesAreRecognised() {
        for address in [
            "https://www.instagram.com/accounts/login/",
            "https://www.instagram.com/accounts/login/?next=%2F",
            "https://instagram.com/accounts/signup/",
            "https://www.instagram.com/accounts/emailsignup/",
            "https://www.instagram.com/accounts/password/reset/",
            "https://www.instagram.com/accounts/onetap/",
        ] {
            XCTAssertTrue(ContentRules.isSignIn(URL(string: address)!), address)
        }

        for address in [
            "https://www.instagram.com/",
            "https://www.instagram.com/direct/inbox/",
            "https://www.instagram.com/login/",
            "https://www.instagram.com/accounts/edit/",
            "https://www.instagram.com/accounts/",
            "https://example.com/accounts/login/",
        ] {
            XCTAssertFalse(ContentRules.isSignIn(URL(string: address)!), address)
        }
    }

    func testFindSomeoneRefusesThingsThatAreNotUsernames() {
        for typed in ["", "   ", "@", "two words", "someone/../else", String(repeating: "a", count: 31)] {
            XCTAssertNil(ContentRules.profile(forHandle: typed), typed)
        }
    }
}
