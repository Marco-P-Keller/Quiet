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

    func testAnAddressNobodyWroteDownIsNotHeldAgainstIt() {
        XCTAssertTrue(ThePlace.isStillShown(nil))
        XCTAssertTrue(ThePlace.isStillShown(""))
    }
}
