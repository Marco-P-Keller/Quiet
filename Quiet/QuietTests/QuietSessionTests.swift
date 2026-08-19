import XCTest
@testable import Quiet

@MainActor
final class QuietSessionTests: XCTestCase {
    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    /// Everything one test needs, built fresh so no test can lean on another.
    private struct World {
        let store: MemoryStore
        let time: FakeTime
        let session: QuietSession
    }

    /// Noon, well away from any day boundary.
    private let noon = Date(timeIntervalSince1970: 1_800_000_000)

    private var today: DayKey { DayKey(noon) }

    private func makeWorld(limit: LimitState? = nil, used: TimeInterval = 0) -> World {
        let store = MemoryStore()
        if let limit {
            var ledger = UsageLedger(day: today)
            ledger.add(used)
            store.save(today, for: .setupDay)
            store.save(limit, for: .limit)
            store.save(ledger, for: .usage)
        }
        let time = FakeTime(noon)
        let session = QuietSession(store: store, clock: MonotonicClock(base: time, store: store))
        return World(store: store, time: time, session: session)
    }

    // MARK: - First run

    func testAFreshInstallAsksTheQuestion() {
        let world = makeWorld()
        world.session.start()
        XCTAssertEqual(world.session.screen, .setup)
    }

    func testSetupAppliesImmediatelyAndSurvivesARelaunch() {
        let world = makeWorld()
        world.session.start()
        world.session.completeSetup(minutes: 30)
        XCTAssertEqual(world.session.screen, .browsing)
        XCTAssertEqual(world.session.limit.minutes, 30)

        let relaunched = QuietSession(
            store: world.store,
            clock: MonotonicClock(base: world.time, store: world.store)
        )
        relaunched.start()
        XCTAssertEqual(relaunched.screen, .browsing)
        XCTAssertEqual(relaunched.limit.minutes, 30)
    }

    /// The hidden gesture is explained on the first launch of each of the first
    /// three days, and then never again.
    func testTheGestureIsTaughtForThreeDaysAndThenLetGo() {
        let world = makeWorld()
        world.session.start()
        XCTAssertFalse(world.session.isLearningTheGesture, "nothing to teach before there is an app to use")

        world.session.completeSetup(minutes: 20)
        XCTAssertTrue(world.session.isLearningTheGesture)

        world.time.now = noon.addingTimeInterval(2 * 24 * 3600)
        XCTAssertTrue(world.session.isLearningTheGesture)

        world.time.now = noon.addingTimeInterval(3 * 24 * 3600)
        XCTAssertFalse(world.session.isLearningTheGesture)
    }

    // MARK: - The curtain

    func testASpentDayOpensOnTheCurtain() {
        let world = makeWorld(limit: LimitState(minutes: 20), used: 20 * 60)
        world.session.start()
        XCTAssertEqual(world.session.screen, .spent)
        XCTAssertEqual(world.session.remaining, 0)
    }

    func testLoweringTheLimitBelowWhatIsSpentEndsTheDay() {
        let world = makeWorld(limit: LimitState(minutes: 60), used: 30 * 60)
        world.session.start()
        XCTAssertEqual(world.session.screen, .browsing)

        world.session.requestLimit(15)
        XCTAssertEqual(world.session.screen, .spent)
    }

    /// The property that makes it safe to put a way into the panel on the
    /// curtain: nothing reachable from there can give today's time back.
    func testNothingAskedForOnTheCurtainCanReopenToday() {
        let world = makeWorld(limit: LimitState(minutes: 20), used: 20 * 60)
        world.session.start()
        XCTAssertEqual(world.session.screen, .spent)

        let result = world.session.requestLimit(240)
        XCTAssertEqual(result, .success(.on(today.next, 240)))
        XCTAssertEqual(world.session.screen, .spent, "today is still over")
        XCTAssertEqual(world.session.limit.minutes, 20)
    }

    // MARK: - A new day

    func testTheDayTurnsAndTheQueuedChangeArrives() {
        let world = makeWorld(limit: LimitState(minutes: 20), used: 20 * 60)
        world.session.start()
        world.session.requestLimit(45)
        XCTAssertEqual(world.session.screen, .spent)

        world.time.now = noon.addingTimeInterval(24 * 3600)
        world.session.setForeground(true)
        defer { world.session.setForeground(false) }

        XCTAssertEqual(world.session.screen, .browsing)
        XCTAssertEqual(world.session.limit.minutes, 45)
        XCTAssertEqual(world.session.ledger.seconds, 0)
        XCTAssertNil(world.session.limit.pending)
    }

    func testAWeekAwayFromThePhoneStillOnlyGrantsOneDay() {
        let world = makeWorld(limit: LimitState(minutes: 20), used: 20 * 60)
        world.session.start()

        world.time.now = noon.addingTimeInterval(9 * 24 * 3600)
        world.session.setForeground(true)
        defer { world.session.setForeground(false) }

        XCTAssertEqual(world.session.screen, .browsing)
        XCTAssertEqual(world.session.remaining, 20 * 60, "one day's worth, not nine")
    }

    // MARK: - Saying how much is left

    /// The bug this pins: `first(where:)` over `[5, 1]` always returns 5, so
    /// the one-minute warning was unreachable and three minutes left announced
    /// itself as five.
    func testTheWarningsComeDueInTheRightOrder() {
        typealias S = QuietSession
        XCTAssertEqual(S.warningsDue(minutesLeft: 6, alreadySaid: []), [])
        XCTAssertEqual(S.warningsDue(minutesLeft: 5, alreadySaid: []), [5])
        XCTAssertEqual(S.warningsDue(minutesLeft: 3, alreadySaid: [5]), [])
        XCTAssertEqual(S.warningsDue(minutesLeft: 1, alreadySaid: [5]), [1])
        XCTAssertEqual(S.warningsDue(minutesLeft: 0, alreadySaid: [5, 1]), [])
    }

    /// Away from the app across both thresholds: it should say the urgent one,
    /// once, and consider the other spent.
    func testComingBackLateSaysTheUrgentWarningOnly() {
        let due = QuietSession.warningsDue(minutesLeft: 1, alreadySaid: [])
        XCTAssertEqual(due, [5, 1])
        XCTAssertEqual(due.min(), 1, "one minute left is not a five-minute warning")
    }

    // MARK: - A rewound clock

    func testRaisingIsRefusedWhileTheClockIsBehind() {
        let world = makeWorld()
        world.session.start()
        world.session.completeSetup(minutes: 20)

        world.time.now = noon.addingTimeInterval(-7 * 24 * 3600)
        XCTAssertTrue(world.session.isClockRewound)
        XCTAssertEqual(world.session.requestLimit(60), .failure(.clockRewound))
    }

    func testLoweringIsStillAllowedWhileTheClockIsBehind() {
        let world = makeWorld()
        world.session.start()
        world.session.completeSetup(minutes: 60)

        world.time.now = noon.addingTimeInterval(-7 * 24 * 3600)
        XCTAssertEqual(world.session.requestLimit(15), .success(.now(15)))
        XCTAssertEqual(world.session.limit.minutes, 15)
    }

    /// A queued increase can still be revised downward while the clock is
    /// behind. Measuring "an increase" against today alone refused a reduction
    /// while the screen said the limit could go down but not up.
    func testAQueuedIncreaseCanStillBeCutWhileTheClockIsBehind() {
        let world = makeWorld(limit: LimitState(minutes: 30))
        world.session.start()
        XCTAssertEqual(world.session.requestLimit(120), .success(.on(today.next, 120)))

        world.time.now = noon.addingTimeInterval(-7 * 24 * 3600)
        XCTAssertTrue(world.session.isClockRewound)

        XCTAssertEqual(
            world.session.requestLimit(45),
            .success(.on(today.next, 45)),
            "asking for less than what is already queued is asking for less"
        )
        XCTAssertEqual(world.session.requestLimit(240), .failure(.clockRewound))
    }

    func testTurningTheClockBackDoesNotHandOutANewDay() {
        let world = makeWorld(limit: LimitState(minutes: 20), used: 20 * 60)
        world.session.start()
        XCTAssertEqual(world.session.screen, .spent)

        world.time.now = noon.addingTimeInterval(-2 * 24 * 3600)
        world.session.setForeground(true)
        defer { world.session.setForeground(false) }

        XCTAssertEqual(world.session.screen, .spent)
        XCTAssertEqual(world.session.remaining, 0)
    }
}
