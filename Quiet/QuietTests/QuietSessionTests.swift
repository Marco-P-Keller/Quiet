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
            store.save(true, for: .setupComplete)
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
