import WebKit
import XCTest
@testable import Quiet

/// Coming back to where you were is a courtesy with a short shelf life, and
/// both halves of that are judgement rather than plumbing.
final class ThePlaceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func minutesAgo(_ minutes: Double) -> TimeInterval {
        now.timeIntervalSince1970 - minutes * 60
    }

    func testWhereYouWereAMomentAgoIsWhereYouWere() {
        XCTAssertTrue(ThePlace.isFresh(minutesAgo(2), now: now))
    }

    func testThisMorningIsNot() {
        XCTAssertFalse(
            ThePlace.isFresh(minutesAgo(90), now: now),
            "an app that reopens on this morning's feed has not noticed the day moved on"
        )
    }

    func testTheEdgeIsTwentyMinutes() {
        XCTAssertTrue(ThePlace.isFresh(minutesAgo(19.9), now: now))
        XCTAssertFalse(ThePlace.isFresh(minutesAgo(20.1), now: now))
    }

    func testNothingWrittenDownIsNotAPlace() {
        XCTAssertFalse(ThePlace.isFresh(0, now: now))
    }

    /// A clock that moved is not a place, and believing it would restore a page
    /// from any distance at all.
    func testAPlaceFromTheFutureIsRefused() {
        XCTAssertFalse(ThePlace.isFresh(now.timeIntervalSince1970 + 600, now: now))
    }

    // MARK: - The feed goes stale sooner

    func testAShortLookAwayKeepsTheFeed() {
        let left = now.addingTimeInterval(-3 * 60)
        XCTAssertFalse(ThePlace.feedIsStale(since: left, now: now))
    }

    func testALongerAbsenceStartsTheFeedOver() {
        let left = now.addingTimeInterval(-11 * 60)
        XCTAssertTrue(ThePlace.feedIsStale(since: left, now: now))
    }

    func testAClockThatMovedBackwardsIsNotAnAbsence() {
        XCTAssertFalse(ThePlace.feedIsStale(since: now.addingTimeInterval(600), now: now))
    }

    func testTheFeedIsStalerThanAProfile() {
        XCTAssertLessThan(ThePlace.feedGoesStale, ThePlace.fresh)
    }

    // MARK: - What it is allowed to put back

    /// A restored state never passes the navigation delegate, so the URL rules
    /// never see it. This is the door that closes.
    func testAPageTheAppRefusesIsNotRestored() {
        XCTAssertFalse(ThePlace.isStillShown("https://www.instagram.com/reels/"))
        XCTAssertFalse(ThePlace.isStillShown("https://www.instagram.com/explore/"))
    }

    func testAnOrdinaryPageIs() {
        XCTAssertTrue(ThePlace.isStillShown("https://www.instagram.com/"))
        XCTAssertTrue(ThePlace.isStillShown("https://www.instagram.com/marco/"))
        XCTAssertTrue(ThePlace.isStillShown("https://www.instagram.com/direct/inbox/"))
    }

    /// A place from before addresses were kept has no address key at all.
    func testAnAddressNobodyWroteDownIsNotHeldAgainstIt() {
        XCTAssertTrue(ThePlace.isStillShown(nil))
    }

    /// Written down empty is a pane that had no page — not a place.
    func testAnEmptyAddressIsNotAPlace() {
        XCTAssertFalse(ThePlace.isStillShown(""))
    }

    func testAPageOfSigningInIsNotAPlace() {
        XCTAssertFalse(ThePlace.isStillShown("https://www.instagram.com/accounts/login/"))
        XCTAssertFalse(ThePlace.isStillShown("https://www.instagram.com/accounts/onetap/?next=%2F"))
    }
}

/// The real web view, because the failure was WebKit's answer rather than the
/// app's arithmetic.
///
/// Measured on 2026-10-23 before the fix: a web view with no page hands over
/// 137 bytes of `interactionState`, and putting them into a fresh one leaves it
/// with no address, nothing loading and no current item — which a pane read as
/// "restored", opened nothing else, and after eight seconds called "Instagram
/// did not answer". That was the screen after signing in.
@MainActor
final class ThePlaceOnAWebViewTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "ThePlaceOnAWebViewTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAPaneWithNoPageIsNotAPlace() {
        let empty = WKWebView()
        XCTAssertNotNil(empty.interactionState as? Data, "WebKit stopped handing state over for an empty view; the guard is still right")

        ThePlace.keep(empty, for: .home, in: defaults)

        XCTAssertNil(defaults.data(forKey: ThePlace.key(ThePlace.state, .home)))
        XCTAssertFalse(ThePlace.restore(into: WKWebView(), for: .home, in: defaults))
    }

    func testKeepingNothingForgetsWhatWasThere() {
        defaults.set(Data([1]), forKey: ThePlace.key(ThePlace.state, .messages))
        defaults.set(Date().timeIntervalSince1970, forKey: ThePlace.key(ThePlace.when, .messages))

        ThePlace.keep(WKWebView(), for: .messages, in: defaults)

        XCTAssertNil(defaults.data(forKey: ThePlace.key(ThePlace.state, .messages)))
    }

    /// What an older build wrote down for a pane with no page: state, a time,
    /// and no address key. Put back, it must not count as a page.
    func testAPlaceThatPutsNothingBackIsNotARestore() throws {
        let data = try XCTUnwrap(WKWebView().interactionState as? Data)
        defaults.set(data, forKey: ThePlace.key(ThePlace.state, .home))
        defaults.set(Date().timeIntervalSince1970, forKey: ThePlace.key(ThePlace.when, .home))

        let fresh = WKWebView()
        XCTAssertFalse(ThePlace.restore(into: fresh, for: .home, in: defaults))
        XCTAssertNil(defaults.data(forKey: ThePlace.key(ThePlace.state, .home)), "and it is forgotten")
    }
}

