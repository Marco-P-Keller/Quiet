import XCTest
@testable import Quiet

/// The rule that decides whether the App Store's question is ever put.
///
/// Worth testing carefully for a reason that has nothing to do with the code:
/// this is the one thing in Quiet that interrupts somebody for the app's
/// benefit rather than theirs. A defect here is not a wrong pixel, it is the
/// app nagging.
@MainActor
final class ApplauseTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var clock: TimeInterval = 0

    override func setUp() {
        super.setUp()
        suite = "quiet.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        clock = 1_000
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func made() -> Applause {
        Applause(defaults: defaults, uptime: { [unowned self] in self.clock })
    }

    func testAFreshInstallOwesFiveMinutes() {
        let applause = made()
        XCTAssertEqual(applause.spent, 0)
        XCTAssertFalse(applause.isDue)
        XCTAssertEqual(applause.remaining, 5 * 60)
    }

    /// Time passing is not the test. Time passing *with the app on screen* is.
    func testTimeWhileTheAppIsAwayCountsForNothing() {
        let applause = made()
        clock += 10 * 60
        applause.bank()
        XCTAssertEqual(applause.spent, 0)
        XCTAssertFalse(applause.isDue)
    }

    func testTimeOnScreenAddsUp() {
        let applause = made()
        applause.enter()
        clock += 90
        applause.bank()
        XCTAssertEqual(applause.spent, 90, accuracy: 0.001)
        XCTAssertEqual(applause.remaining, 5 * 60 - 90, accuracy: 0.001)
        XCTAssertFalse(applause.isDue)
    }

    /// Quiet is built to be used in short sittings. A rule that only fired in
    /// one long one would fire for the people using the app worst.
    func testItAddsUpAcrossSittingsAndLaunches() {
        for _ in 0..<5 {
            let applause = made()
            applause.enter()
            clock += 61
            applause.leave()
        }
        let later = made()
        XCTAssertTrue(later.isDue)
        XCTAssertEqual(later.remaining, 0)
    }

    func testItIsAskedOnceAndThenNeverAgain() {
        let first = made()
        first.enter()
        clock += 5 * 60
        first.bank()
        XCTAssertTrue(first.isDue)

        first.markAsked()
        XCTAssertFalse(first.isDue)

        clock += 60 * 60
        let next = made()
        XCTAssertTrue(next.asked)
        XCTAssertFalse(next.isDue)
    }

    /// A phone that spent the night asleep and woke into the foreground is not
    /// somebody who used the app all night.
    func testAJumpTheSizeOfANightIsNotFiveMinutes() {
        let applause = made()
        applause.enter()
        clock += 8 * 60 * 60
        applause.bank()
        XCTAssertEqual(applause.spent, 0)
        XCTAssertFalse(applause.isDue)
    }

    /// Coming to the front twice without leaving must not restart the clock,
    /// which would make every quick glance worth nothing.
    func testEnteringTwiceDoesNotThrowAwayWhatIsOwed() {
        let applause = made()
        applause.enter()
        clock += 100
        applause.enter()
        applause.bank()
        XCTAssertEqual(applause.spent, 100, accuracy: 0.001)
    }

    func testLeavingBanksWhatIsOwedAndStops() {
        let applause = made()
        applause.enter()
        clock += 30
        applause.leave()
        clock += 10 * 60
        applause.bank()
        XCTAssertEqual(applause.spent, 30, accuracy: 0.001)
    }

    func testARehearsalCanForgetIt() {
        let applause = made()
        applause.enter()
        clock += 5 * 60
        applause.leave()
        applause.markAsked()

        Applause.forget(defaults: defaults)

        let fresh = made()
        XCTAssertEqual(fresh.spent, 0)
        XCTAssertFalse(fresh.asked)
    }
}
