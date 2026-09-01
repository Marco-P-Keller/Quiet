import XCTest
@testable import Quiet

/// The pull at the top has to survive every one of these, because losing it is
/// the failure that looks like nothing at all: a gesture everybody expects,
/// gone, with no message and nothing to press.
final class OverscrollTests: XCTestCase {
    private let screen: CGFloat = 800

    func testTheTopBounces() {
        XCTAssertTrue(Overscroll.bounces(travelled: 0, screen: screen))
    }

    func testJustBelowTheTopStillBounces() {
        XCTAssertTrue(Overscroll.bounces(travelled: 120, screen: screen))
    }

    /// The one this exists for. A feed is thousands of points long; a screen
    /// down it, the only edge a thumb can reach is the bottom one.
    func testAScreenDownDoesNot() {
        XCTAssertTrue(Overscroll.bounces(travelled: screen - 1, screen: screen))
        XCTAssertFalse(Overscroll.bounces(travelled: screen, screen: screen))
        XCTAssertFalse(Overscroll.bounces(travelled: 40_000, screen: screen))
    }

    /// Already pulled: the offset is above the top of the page and therefore
    /// negative. Answering anything but yes here would take the bounce away
    /// mid-gesture, under a thumb that is holding it.
    func testAPullInProgressKeepsIt() {
        XCTAssertTrue(Overscroll.bounces(travelled: -90, screen: screen))
    }

    /// Before the first layout there is no glass to measure against, and a
    /// zero would otherwise read as "a screen down" and refuse the pull on
    /// every page that has not been laid out yet.
    func testNoScreenYetKeepsIt() {
        XCTAssertTrue(Overscroll.bounces(travelled: 0, screen: 0))
        XCTAssertTrue(Overscroll.bounces(travelled: 500, screen: 0))
    }

    /// A profile with four posts. There is no screen of page to be below, so
    /// the answer stays yes everywhere on it — which is the trade this rule
    /// makes on purpose: the pull is worth more than an inch of spring.
    func testAShortPageKeepsItEverywhere() {
        for travelled in stride(from: CGFloat(0), through: 200, by: 25) {
            XCTAssertTrue(Overscroll.bounces(travelled: travelled, screen: screen))
        }
    }
}
