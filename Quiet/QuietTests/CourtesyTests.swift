import XCTest
@testable import Quiet

/// The end of the day arriving mid-sentence.
///
/// The app is meant to be strict. It is not meant to be rude, and taking half a
/// message away is rude — so the curtain waits, once, for twenty seconds. This
/// is the one place where the limit bends, so every edge of it is pinned here.
@MainActor
final class CourtesyTests: XCTestCase {
    private final class HandCranked: Heartbeat {
        private var beat: (@MainActor () -> Void)?
        func start(every interval: TimeInterval, _ beat: @escaping @MainActor () -> Void) {
            self.beat = beat
        }
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

    private final class QuietRinger: Ringer {
        func ask() async -> Bool { true }
        func ring(at times: [Date]) {}
        func silence() {}
    }

    private final class NoCloud: Cloud {
        func fetch() async -> Carried? { nil }
        func put(_ carried: Carried) async {}
        func forget() async {}
    }

    private let noon = Date(timeIntervalSince1970: 1_800_000_000)
    private var today: DayKey { DayKey(noon) }
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        suites = []
        super.tearDown()
    }

    @MainActor
    private struct World {
        let time: FakeTime
        let uptime: Uptime
        let beat: HandCranked
        let session: QuietSession

        /// Spend `seconds` with Instagram on screen.
        func spend(_ seconds: TimeInterval) {
            for _ in 0..<Int(seconds) {
                uptime.seconds += 1
                time.now = time.now.addingTimeInterval(1)
                beat.tick()
            }
        }
    }

    /// A minute's limit, so the day can be run out in a test without a loop
    /// that takes a minute of its own.
    private func makeWorld(used: TimeInterval = 55) -> World {
        let store = MemoryStore()
        var ledger = UsageLedger(day: today, endsAt: today.end())
        ledger.add(used)
        store.save(today, for: .setupDay)
        store.save(LimitState(minutes: 1), for: .limit)
        store.save(ledger, for: .usage)

        let suite = "quiet.tests.\(UUID().uuidString)"
        suites.append(suite)
        let preferences = Preferences(defaults: UserDefaults(suiteName: suite)!)

        let time = FakeTime(noon)
        let uptime = Uptime()
        let beat = HandCranked()
        let session = QuietSession(
            store: store,
            clock: MonotonicClock(base: time, store: store, uptime: uptime.reading),
            preferences: preferences,
            heartbeat: beat,
            uptime: uptime.reading,
            ringer: QuietRinger(),
            cloud: NoCloud(),
            phone: "here"
        )
        session.start()
        session.setForeground(true)
        return World(time: time, uptime: uptime, beat: beat, session: session)
    }

    func testWithNobodyTypingTheDayEndsOnTime() {
        let world = makeWorld()
        world.spend(10)
        XCTAssertEqual(world.session.screen, .spent)
    }

    func testTheCurtainWaitsForSomebodyMidSentence() {
        let world = makeWorld()
        world.session.setTyping(true)
        world.spend(10)
        XCTAssertEqual(world.session.screen, .browsing, "the sentence is not finished")
    }

    func testAndComesDownTwentySecondsLater() {
        let world = makeWorld()
        world.session.setTyping(true)
        world.spend(10)
        XCTAssertEqual(world.session.screen, .browsing)

        world.spend(QuietSession.courtesy + 1)

        XCTAssertEqual(world.session.screen, .spent, "twenty seconds is the whole of it")
    }

    /// The time is not a gift. It is spent like every other second, so the day
    /// simply ends a little over rather than a little later.
    func testTheBorrowedSecondsAreStillCounted() {
        let world = makeWorld()
        world.session.setTyping(true)
        world.spend(10)
        XCTAssertEqual(world.session.remaining, 0)
    }

    func testStoppingEndsItAtOnce() {
        let world = makeWorld()
        world.session.setTyping(true)
        world.spend(10)
        XCTAssertEqual(world.session.screen, .browsing)

        world.session.setTyping(false)

        XCTAssertEqual(world.session.screen, .spent, "the sentence is finished")
    }

    /// The door this closes: otherwise the day could be extended twenty seconds
    /// at a time, for as long as somebody kept tapping into a message box.
    func testItCannotBeHadTwice() {
        let world = makeWorld()
        world.session.setTyping(true)
        world.spend(10)
        world.session.setTyping(false)
        XCTAssertEqual(world.session.screen, .spent)

        world.session.setTyping(true)

        XCTAssertEqual(world.session.screen, .spent, "once a day, and it has been had")
    }
}
