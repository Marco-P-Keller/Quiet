import XCTest
@testable import Quiet

/// The limit, reaching the Instagram app.
///
/// Screen Time itself cannot run in a test and its tokens cannot be made by
/// one, so everything that decides anything is kept apart from it and tested
/// here: the marks Screen Time is asked to report at, the sum that decides the
/// day is over, the rule that lets the reach grow at once and shrink only
/// tomorrow, and the session folding the Instagram app's minutes into the day.
@MainActor
final class InstagramAppTests: XCTestCase {

    // MARK: - The marks

    func testUpToAnHourEveryMinuteIsAMark() {
        XCTAssertEqual(Milestones.marks(upTo: 20), Array(1...20))
        XCTAssertEqual(Milestones.marks(upTo: 60), Array(1...60))
    }

    /// Past an hour the marks spread out, and the limit itself is always one
    /// of them, so the app closes at the limit and not at the mark before it.
    func testPastAnHourThereAreNeverMoreThanSixtyAndTheLimitIsAlwaysOne() {
        for top in [61, 90, 119, 120, 179, 240] {
            let marks = Milestones.marks(upTo: top)
            XCTAssertLessThanOrEqual(marks.count, Milestones.most + 1, "top \(top)")
            XCTAssertEqual(marks.last, top, "top \(top)")
            XCTAssertEqual(marks, marks.sorted(), "top \(top)")
            XCTAssertEqual(Set(marks).count, marks.count, "top \(top)")
        }
        XCTAssertTrue(Milestones.marks(upTo: 0).isEmpty)
    }

    func testAMarkReadsBackAsItsMinutes() {
        XCTAssertEqual(Milestones.minutes(Milestones.name(17)), 17)
        XCTAssertNil(Milestones.minutes("somebody.else.17"))
        XCTAssertNil(Milestones.minutes("quiet.minute.x"))
    }

    /// Tomorrow's bigger number is already watched for, so it is not missed on
    /// the morning it takes over.
    func testTheTopIsTheLargerOfTheLimitAndOneWaiting() {
        let today = DayKey(ordinal: 9_000)
        var limit = LimitState(minutes: 20)
        XCTAssertEqual(Milestones.top(for: limit), 20)
        limit.pending = PendingChange(minutes: 45, effective: today.next)
        XCTAssertEqual(Milestones.top(for: limit), 45)
    }

    // MARK: - The tally

    func testTheTallyOnlyGoesUpWithinADay() {
        let day = DayKey(ordinal: 9_000)
        let tally = Tally(day: day, minutes: 12)
        XCTAssertEqual(tally.reaching(5, on: day).minutes, 12, "a repeated earlier mark is not a step back")
        XCTAssertEqual(tally.reaching(13, on: day).minutes, 13)
        XCTAssertEqual(tally.reaching(2, on: day.next), Tally(day: day.next, minutes: 2), "a new day starts from what it reports")
    }

    // MARK: - The sum

    private let today = DayKey(ordinal: 9_000)

    private func terms(limit: Int = 20, day: DayKey? = nil, inQuiet minutes: Double = 0) -> Terms {
        Terms(limit: LimitState(minutes: limit), day: day ?? today, spentInQuiet: minutes * 60)
    }

    func testTheDayIsOverWhenBothDoorsTogetherReachTheLimit() {
        XCTAssertFalse(Verdict.isOver(tally: Tally(day: today, minutes: 4), terms: terms(inQuiet: 15), today: today))
        XCTAssertTrue(Verdict.isOver(tally: Tally(day: today, minutes: 5), terms: terms(inQuiet: 15), today: today))
        XCTAssertTrue(Verdict.isOver(tally: Tally(day: today, minutes: 20), terms: terms(), today: today))
    }

    /// A day Quiet has not been opened on yet: what it spent yesterday is not
    /// today's, and neither is yesterday's tally.
    func testYesterdayCountsForNothing() {
        XCTAssertFalse(Verdict.isOver(
            tally: Tally(day: today, minutes: 10),
            terms: terms(day: today.adding(days: -1), inQuiet: 19),
            today: today
        ))
        XCTAssertFalse(Verdict.isOver(
            tally: Tally(day: today.adding(days: -1), minutes: 30),
            terms: terms(),
            today: today
        ))
    }

    /// An increase that took effect this morning is the limit, even if Quiet
    /// has not been opened since to roll it in.
    func testAnIncreaseThatHasComeDueIsTheLimit() {
        var limit = LimitState(minutes: 20)
        limit.pending = PendingChange(minutes: 40, effective: today)
        let terms = Terms(limit: limit, day: today, spentInQuiet: 0)
        XCTAssertFalse(Verdict.isOver(tally: Tally(day: today, minutes: 30), terms: terms, today: today))
        XCTAssertTrue(Verdict.isOver(tally: Tally(day: today, minutes: 40), terms: terms, today: today))
    }

    /// Without terms Quiet has never said what the limit is, and nothing is
    /// closed on a guess.
    func testNoTermsNeverCloses() {
        XCTAssertFalse(Verdict.isOver(tally: Tally(day: today, minutes: 600), terms: nil, today: today))
    }

    // MARK: - The reach

    private typealias Apps = Set<Int>
    private func covers(_ wanted: Apps?, _ current: Apps?) -> Bool {
        (wanted ?? []).isSuperset(of: current ?? [])
    }

    func testReachingFurtherAppliesAtOnce() {
        let off = Reach<Apps>()
        let on = off.requesting([1], today: today, covers: covers)
        XCTAssertEqual(on.current, [1])
        XCTAssertNil(on.narrowing)

        let more = on.requesting([1, 2], today: today, covers: covers)
        XCTAssertEqual(more.current, [1, 2])
        XCTAssertNil(more.narrowing)
    }

    /// The whole point: switching it off with the curtain down does nothing
    /// until tomorrow.
    func testSwitchingOffWaitsForTomorrow() {
        let on = Reach<Apps>(current: [1])
        let asked = on.requesting(nil, today: today, covers: covers)
        XCTAssertEqual(asked.current, [1], "today it still reaches the app")
        XCTAssertEqual(asked.narrowing?.from, today.next)

        XCTAssertEqual(asked.rolled(to: today).current, [1])
        XCTAssertNil(asked.rolled(to: today.next).current)
        XCTAssertNil(asked.rolled(to: today.next).narrowing)
    }

    func testTakingOneAppAwayWaitsToo() {
        let on = Reach<Apps>(current: [1, 2])
        let asked = on.requesting([1], today: today, covers: covers)
        XCTAssertEqual(asked.current, [1, 2])
        XCTAssertEqual(asked.rolled(to: today.next).current, [1])
    }

    /// Changing your mind back costs nothing: keeping what you have is more
    /// than the narrowing would have left.
    func testKeepingWhatYouHaveCancelsTheNarrowing() {
        let asked = Reach<Apps>(current: [1]).requesting(nil, today: today, covers: covers)
        let kept = asked.requesting([1], today: today, covers: covers)
        XCTAssertEqual(kept, Reach(current: [1]))
    }

    /// Asking again the next day does not restart the wait: the narrowing that
    /// came due is applied first.
    func testANarrowingThatCameDueIsAppliedBeforeTheNextQuestion() {
        let asked = Reach<Apps>(current: [1, 2]).requesting([1], today: today, covers: covers)
        let next = asked.requesting([1, 3], today: today.next, covers: covers)
        XCTAssertEqual(next.current, [1, 3])
        XCTAssertNil(next.narrowing)
    }

    func testTheReachSurvivesBeingWrittenDown() throws {
        let asked = Reach<Apps>(current: [1, 2]).requesting([1], today: today, covers: covers)
        let data = try JSONEncoder().encode(asked)
        XCTAssertEqual(try JSONDecoder().decode(Reach<Apps>.self, from: data), asked)
    }

    // MARK: - The ledger

    func testTheLedgerTakesOnlyWhatIsNew() {
        var ledger = UsageLedger(day: today, seconds: 120)
        XCTAssertTrue(ledger.credit(appMinutes: 3))
        XCTAssertEqual(ledger.seconds, 300)
        XCTAssertFalse(ledger.credit(appMinutes: 3), "the same report read twice")
        XCTAssertFalse(ledger.credit(appMinutes: 2), "an older report")
        XCTAssertTrue(ledger.credit(appMinutes: 5))
        XCTAssertEqual(ledger.seconds, 420)
        XCTAssertEqual(ledger.secondsInQuiet, 120)
    }

    /// An afternoon in the Instagram app while Quiet sat closed is one large
    /// number, and a true one. The rule against implausible ticks is about a
    /// clock that jumped, not about this.
    func testAnAfternoonInTheAppIsNotTakenForAClockJump() {
        var ledger = UsageLedger(day: today)
        ledger.credit(appMinutes: 150)
        XCTAssertEqual(ledger.seconds, 150 * 60)
    }

    func testANewDayStartsWithNothingFromTheApp() {
        var ledger = UsageLedger(day: today, seconds: 60)
        ledger.credit(appMinutes: 4)
        ledger.roll(to: today.next)
        XCTAssertNil(ledger.fromTheApp)
        XCTAssertEqual(ledger.seconds, 0)
        XCTAssertTrue(ledger.credit(appMinutes: 1))
        XCTAssertEqual(ledger.seconds, 60)
    }

    /// Ledgers written before the limit could reach the app still load.
    func testALedgerFromBeforeStillLoads() throws {
        let old = #"{"day":{"ordinal":9000},"seconds":42}"#.data(using: .utf8)!
        let ledger = try JSONDecoder().decode(UsageLedger.self, from: old)
        XCTAssertEqual(ledger.seconds, 42)
        XCTAssertNil(ledger.fromTheApp)
        XCTAssertEqual(ledger.secondsInQuiet, 42)
    }

    // MARK: - The session

    /// The Instagram app, as a test can drive it.
    private final class FakeDoor: InstagramAppDoor {
        var reported: [DayKey: Int] = [:]
        private(set) var told: [Terms] = []
        private(set) var closings: [(until: Date, today: DayKey)] = []
        private(set) var mornings = 0
        private(set) var forgotten = false

        func minutes(on day: DayKey) -> Int { reported[day] ?? 0 }
        func tell(_ terms: Terms) { told.append(terms) }
        func close(until: Date, today: DayKey) { closings.append((until, today)) }
        func morning(now: Date, today: DayKey) { mornings += 1 }
        func forget() { forgotten = true }
    }

    private final class HandCranked: Heartbeat {
        private var beat: (@MainActor () -> Void)?
        func start(every interval: TimeInterval, _ beat: @escaping @MainActor () -> Void) { self.beat = beat }
        func stop() {}
        func tick() { beat?() }
    }

    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private final class Uptime {
        var seconds: TimeInterval = 10_000
        var reading: () -> TimeInterval { { [self] in seconds } }
    }

    private let noon = Date(timeIntervalSince1970: 1_800_000_000)
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites { UserDefaults().removePersistentDomain(forName: suite) }
        suites = []
        super.tearDown()
    }

    @MainActor
    private struct World {
        let door: FakeDoor
        let time: FakeTime
        let uptime: Uptime
        let beat: HandCranked
        let session: QuietSession

        func spend(_ seconds: Int) {
            for _ in 0..<seconds {
                uptime.seconds += 1
                time.now = time.now.addingTimeInterval(1)
                beat.tick()
            }
        }

        /// Away in another app, and back.
        func comeBack() {
            session.setForeground(false)
            session.setForeground(true)
        }
    }

    private func makeWorld(limit: Int = 20, reported: Int = 0) -> World {
        let day = DayKey(noon)
        let store = MemoryStore()
        store.save(day, for: .setupDay)
        store.save(LimitState(minutes: limit), for: .limit)
        store.save(UsageLedger(day: day, endsAt: day.end()), for: .usage)

        let suite = "quiet.tests.\(UUID().uuidString)"
        suites.append(suite)
        let preferences = Preferences(defaults: UserDefaults(suiteName: suite)!)
        preferences.saysWhatIsLeft = false

        let door = FakeDoor()
        door.reported[day] = reported
        let time = FakeTime(noon)
        let uptime = Uptime()
        let beat = HandCranked()
        let session = QuietSession(
            store: store,
            clock: MonotonicClock(base: time, store: store, uptime: uptime.reading),
            preferences: preferences,
            heartbeat: beat,
            uptime: uptime.reading,
            door: door
        )
        session.start()
        session.setForeground(true)
        return World(door: door, time: time, uptime: uptime, beat: beat, session: session)
    }

    func testMinutesInTheAppAreSpentFromTheSameDay() {
        let world = makeWorld(limit: 20, reported: 15)
        XCTAssertEqual(world.session.remaining, 5 * 60, accuracy: 0.5)
        XCTAssertEqual(world.session.minutesInTheApp, 15)
        XCTAssertEqual(world.session.screen, .browsing)
    }

    /// The Instagram app spent the rest of the day while Quiet was away; Quiet
    /// opens onto the curtain, not onto a feed that closes a second later.
    func testTheAppSpendingTheDayBringsTheCurtainDownInQuiet() {
        let world = makeWorld(limit: 20, reported: 5)
        world.spend(10 * 60)
        XCTAssertEqual(world.session.screen, .browsing)

        world.door.reported[DayKey(noon)] = 10
        world.comeBack()
        XCTAssertEqual(world.session.screen, .spent)
    }

    /// And the other way round: Quiet spending the day closes the app.
    func testQuietSpendingTheDayClosesTheApp() {
        let world = makeWorld(limit: 5)
        XCTAssertTrue(world.door.closings.isEmpty)
        world.spend(5 * 60)
        XCTAssertEqual(world.session.screen, .spent)
        XCTAssertEqual(world.door.closings.count, 1)
        XCTAssertEqual(world.door.closings.first?.until, world.session.resetsAt)
    }

    /// The extension is told what Quiet itself has spent — never the app's own
    /// share back again, which would count it twice.
    func testTheExtensionIsToldOnlyQuietsOwnShare() {
        let world = makeWorld(limit: 30, reported: 7)
        world.spend(60)
        world.session.checkpoint()
        let last = try? XCTUnwrap(world.door.told.last)
        XCTAssertEqual(last?.spentInQuiet ?? -1, 60, accuracy: 1.5)
        XCTAssertEqual(last?.limit.minutes, 30)
        XCTAssertEqual(last?.day, DayKey(noon))
    }

    func testTheSameReportIsCountedOnce() {
        let world = makeWorld(limit: 30, reported: 7)
        world.comeBack()
        world.comeBack()
        XCTAssertEqual(world.session.remaining, 23 * 60, accuracy: 0.5)
    }

    /// Every time the app comes forward is a chance to open what was closed for
    /// a day that has ended, in case Screen Time's own call at four never came.
    func testComingForwardAsksWhetherADayHasBegun() {
        let world = makeWorld()
        let before = world.door.mornings
        world.comeBack()
        XCTAssertGreaterThan(world.door.mornings, before)
    }
}
