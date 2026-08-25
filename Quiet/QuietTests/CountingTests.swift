import XCTest
@testable import Quiet

/// The day being spent, second by second.
///
/// Everything here happens inside a tick, and until the heartbeat could be
/// handed in, a tick could only be produced by waiting for one. So none of it
/// was tested: not the ledger accruing, not the two warnings, not the moment
/// the curtain arrives. These run the clock as fast as it can be asked to run.
@MainActor
final class CountingTests: XCTestCase {
    /// A heartbeat that beats when a test says so.
    private final class HandCranked: Heartbeat {
        private var beat: (@MainActor () -> Void)?
        private(set) var isRunning = false

        func start(every interval: TimeInterval, _ beat: @escaping @MainActor () -> Void) {
            self.beat = beat
            isRunning = true
        }

        func stop() {
            isRunning = false
        }

        /// One second of the app being looked at.
        func tick() {
            beat?()
        }
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
    private var today: DayKey { DayKey(noon) }

    /// Every preference suite a test made, so none of them outlive it.
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        suites = []
        super.tearDown()
    }

    private struct World {
        let store: MemoryStore
        let time: FakeTime
        let uptime: Uptime
        let beat: HandCranked
        let session: QuietSession

        /// Spend `seconds` with Instagram on screen.
        ///
        /// The two clocks move together, which is what actually happens: real
        /// time passes and the wall clock agrees about it. A test that moved
        /// only one of them would be testing a phone that had been tampered
        /// with, which is a different file.
        func spend(_ seconds: TimeInterval) {
            for _ in 0..<Int(seconds) {
                uptime.seconds += 1
                time.now = time.now.addingTimeInterval(1)
                beat.tick()
            }
        }
    }

    private func makeWorld(
        limit: Int = 20,
        used: TimeInterval = 0,
        speaks: Bool = true
    ) -> World {
        let store = MemoryStore()
        var ledger = UsageLedger(day: today, endsAt: today.end())
        ledger.add(used)
        store.save(today, for: .setupDay)
        store.save(LimitState(minutes: limit), for: .limit)
        store.save(ledger, for: .usage)

        let suite = "quiet.tests.\(UUID().uuidString)"
        suites.append(suite)
        let defaults = UserDefaults(suiteName: suite)!
        let preferences = Preferences(defaults: defaults)
        preferences.saysWhatIsLeft = speaks

        let time = FakeTime(noon)
        let uptime = Uptime()
        let beat = HandCranked()
        let session = QuietSession(
            store: store,
            clock: MonotonicClock(base: time, store: store, uptime: uptime.reading),
            preferences: preferences,
            heartbeat: beat,
            uptime: uptime.reading
        )
        session.start()
        session.setForeground(true)
        return World(store: store, time: time, uptime: uptime, beat: beat, session: session)
    }

    // MARK: - Spending it

    func testTimeOnScreenIsSpent() {
        let world = makeWorld(limit: 20)
        world.spend(60)

        XCTAssertEqual(world.session.remaining, 19 * 60, accuracy: 1.5)
        XCTAssertEqual(world.session.screen, .browsing)
    }

    /// The whole promise, arriving on time.
    func testTheDayEndsWhenItIsSpent() {
        let world = makeWorld(limit: 5)
        world.spend(5 * 60)

        XCTAssertEqual(world.session.screen, .spent)
        XCTAssertEqual(world.session.remaining, 0)
        XCTAssertTrue(
            world.beat.isRunning,
            "the curtain still needs a heartbeat, or nothing notices four in the morning"
        )
    }

    /// Time spent deciding how much time you want is not time on Instagram.
    /// This is the rule that makes the panel free to open.
    func testThePanelIsFree() {
        let world = makeWorld(limit: 20)
        world.session.isPanelShowing = true
        world.spend(120)
        world.session.isPanelShowing = false

        XCTAssertEqual(world.session.remaining, 20 * 60, accuracy: 1.5)
    }

    func testLookingForSomebodyIsFreeToo() {
        let world = makeWorld(limit: 20)
        world.session.isSearchShowing = true
        world.spend(120)
        world.session.isSearchShowing = false

        XCTAssertEqual(world.session.remaining, 20 * 60, accuracy: 1.5)
    }

    /// And the curtain is free, which matters more than it sounds: somebody who
    /// reaches the end of the day and leaves the app open overnight still has
    /// to be given their morning.
    func testTheCurtainSpendsNothingAndStillNoticesTheMorning() {
        let world = makeWorld(limit: 5, used: 5 * 60)
        XCTAssertEqual(world.session.screen, .spent)

        // Four in the morning, arriving while the app sits open on the curtain.
        world.uptime.seconds += 16 * 3600
        world.time.now = today.end().addingTimeInterval(60)
        world.beat.tick()

        XCTAssertEqual(world.session.screen, .browsing)
        XCTAssertEqual(world.session.remaining, 5 * 60)
    }

    // MARK: - What it says on the way down

    func testItSaysFiveMinutesAndThenOne() {
        let world = makeWorld(limit: 7)

        world.spend(60)
        XCTAssertNil(world.session.notice, "seven minutes in is not a warning")

        world.spend(60 + 1)
        XCTAssertNotNil(world.session.notice, "five minutes left is")
        let atFive = world.session.notice

        world.spend(4 * 60)
        XCTAssertNotEqual(world.session.notice, atFive, "and one minute left is again")
    }

    /// The bug this guards: taking the first match in `[5, 1]` is always 5, so
    /// with one minute left the app said "5 minutes left" and the urgent one
    /// could never be reached at all.
    func testArrivingLateSaysTheUrgentOne() {
        let world = makeWorld(limit: 20, used: 19 * 60 + 30)
        world.spend(1)

        guard let notice = world.session.notice else {
            return XCTFail("one minute left is worth saying")
        }
        XCTAssertFalse(
            notice.text.contains("5"),
            "with one minute left, the five-minute warning is not the news"
        )
    }

    func testItSaysNothingTwice() {
        let world = makeWorld(limit: 7)
        world.spend(121)
        let first = world.session.notice
        XCTAssertNotNil(first)

        world.session.dismissNotice(token: first!.token)
        world.spend(30)
        XCTAssertNil(world.session.notice, "the five-minute warning is said once")
    }

    /// Turning the notices off buys nothing. The one argument this app refuses
    /// to have is about how much time there is.
    func testSilenceSaysNothingAndCostsNothing() {
        let world = makeWorld(limit: 7, speaks: false)
        world.spend(121)

        XCTAssertNil(world.session.notice)
        XCTAssertEqual(world.session.remaining, 5 * 60 - 1, accuracy: 1.5)
    }

    // MARK: - The heartbeat itself

    func testItStopsWhenTheAppGoesAway() {
        let world = makeWorld(limit: 20)
        XCTAssertTrue(world.beat.isRunning)

        world.session.setForeground(false)
        XCTAssertFalse(world.beat.isRunning)

        // And what was spent is written down rather than lost.
        XCTAssertNotNil(world.store.load(UsageLedger.self, for: .usage))
    }

    /// A reading the size of a clock jump is not a person looking at a screen,
    /// and crediting it would spend somebody's whole day in one beat.
    func testAnAbsurdReadingIsDropped() {
        let world = makeWorld(limit: 20)
        world.uptime.seconds += 4 * 3600
        world.beat.tick()

        XCTAssertEqual(world.session.remaining, 20 * 60, accuracy: 1)
    }
}
