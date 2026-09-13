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
    /// The day the app is being opened on. An ordinal, the way `DayKey`
    /// counts them, moved by hand so a test can span a week in four lines.
    private var day = 20_000

    override func setUp() {
        super.setUp()
        suite = "quiet.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        clock = 1_000
        day = 20_000
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func made() -> Applause {
        Applause(defaults: defaults, uptime: { [unowned self] in self.clock })
    }

    /// The minutes, banked over as many separate days as the rule asks for.
    /// Used by the tests that are about something else and merely need the
    /// question to be owed.
    private func earnIt() {
        for _ in 0..<Applause.acrossDays {
            let applause = made()
            applause.enter(on: day)
            clock += 2 * 60
            applause.leave()
            day += 1
        }
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
        applause.enter(on: day)
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
            applause.enter(on: day)
            clock += 61
            applause.leave()
            day += 1
        }
        let later = made()
        XCTAssertTrue(later.isDue)
        XCTAssertEqual(later.remaining, 0)
    }

    // MARK: - The three days

    /// The one this rule was changed for.
    ///
    /// Five minutes was the whole test once. At the smallest limit the app
    /// allows, five minutes is somebody's *first sitting* — so the question
    /// went to a person who had opened the app and seen nothing it promises.
    /// The minutes are still necessary and they are no longer sufficient.
    func testAllTheMinutesOnOneDayIsNotEnough() {
        let applause = made()
        applause.enter(on: day)
        clock += 30 * 60
        applause.bank()

        XCTAssertGreaterThanOrEqual(applause.spent, Applause.earned)
        XCTAssertEqual(applause.remaining, 0)
        XCTAssertEqual(applause.days, 1)
        XCTAssertFalse(applause.isDue, "One sitting is not three days")
        XCTAssertEqual(applause.daysRemaining, 2)
    }

    /// Opening the app nine times before lunch is one day, not nine.
    func testTheSameDayManyTimesIsStillOneDay() {
        for _ in 0..<9 {
            let applause = made()
            applause.enter(on: day)
            clock += 60
            applause.leave()
        }
        let later = made()
        XCTAssertEqual(later.days, 1)
        XCTAssertFalse(later.isDue)
    }

    /// And the other way round: three days of barely opening it is not five
    /// minutes, and the question is not owed for turning up either.
    func testThreeDaysWithoutTheMinutesIsNotEnough() {
        for _ in 0..<3 {
            let applause = made()
            applause.enter(on: day)
            clock += 5
            applause.leave()
            day += 1
        }
        let later = made()
        XCTAssertEqual(later.days, 3)
        XCTAssertEqual(later.daysRemaining, 0)
        XCTAssertFalse(later.isDue, "Three glances are not five minutes")
    }

    func testTheMinutesAcrossThreeDaysIsWhatItTakes() {
        earnIt()
        let later = made()
        XCTAssertTrue(later.isDue)
        XCTAssertEqual(later.days, 3)
        XCTAssertEqual(later.daysRemaining, 0)
    }

    /// A day counted is a day remembered, across a launch that happens on it.
    func testTheDayCountSurvivesRelaunching() {
        let first = made()
        first.enter(on: day)
        first.leave()
        XCTAssertEqual(first.days, 1)

        let second = made()
        second.enter(on: day)
        XCTAssertEqual(second.days, 1, "Same day, new launch, still one day")

        day += 1
        let third = made()
        third.enter(on: day)
        XCTAssertEqual(third.days, 2)
    }

    /// Quiet's day turns at four in the morning, so two sittings either side of
    /// midnight are one day. This class never computes that — it is handed an
    /// ordinal — and the point of this test is that it never starts to.
    func testItCountsWhateverDayItIsHanded() {
        let applause = made()
        applause.enter(on: 20_000)
        applause.leave()
        applause.enter(on: 20_000)
        XCTAssertEqual(applause.days, 1)
    }

    // MARK: -

    func testItIsAskedOnceAndThenNeverAgain() {
        earnIt()
        let first = made()
        XCTAssertTrue(first.isDue)

        first.markAsked()
        XCTAssertFalse(first.isDue)

        clock += 60 * 60
        day += 1
        let next = made()
        XCTAssertTrue(next.asked)
        XCTAssertFalse(next.isDue)
    }

    /// A phone that spent the night asleep and woke into the foreground is not
    /// somebody who used the app all night.
    func testAJumpTheSizeOfANightIsNotFiveMinutes() {
        let applause = made()
        applause.enter(on: day)
        clock += 8 * 60 * 60
        applause.bank()
        XCTAssertEqual(applause.spent, 0)
        XCTAssertFalse(applause.isDue)
    }

    /// Coming to the front twice without leaving must not restart the clock,
    /// which would make every quick glance worth nothing.
    func testEnteringTwiceDoesNotThrowAwayWhatIsOwed() {
        let applause = made()
        applause.enter(on: day)
        clock += 100
        applause.enter(on: day)
        applause.bank()
        XCTAssertEqual(applause.spent, 100, accuracy: 0.001)
    }

    func testLeavingBanksWhatIsOwedAndStops() {
        let applause = made()
        applause.enter(on: day)
        clock += 30
        applause.leave()
        clock += 10 * 60
        applause.bank()
        XCTAssertEqual(applause.spent, 30, accuracy: 0.001)
    }

    func testARehearsalCanForgetIt() {
        earnIt()
        let applause = made()
        applause.markAsked()

        Applause.forget(defaults: defaults)

        let fresh = made()
        XCTAssertEqual(fresh.spent, 0)
        XCTAssertFalse(fresh.asked)
        XCTAssertEqual(fresh.days, 0, "A scene that kept two of the three days would photograph the sheet")
        XCTAssertNil(fresh.lastDay)
    }
}
