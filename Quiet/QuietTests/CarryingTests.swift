import XCTest
@testable import Quiet

/// The merge rule is pinned in `CarriedTests`. This is what the session does
/// with it: that a second device is not a second allowance, that nothing is
/// sent until somebody asks, and that being forgotten reaches iCloud too.
@MainActor
final class CarryingTests: XCTestCase {
    /// Isolated explicitly: a type nested inside a main-actor class does not
    /// inherit that isolation, and `Cloud` is a main-actor protocol.
    @MainActor
    private final class FakeCloud: Cloud {
        var stored: Carried?
        private(set) var fetches = 0
        private(set) var puts = 0
        private(set) var forgets = 0

        func fetch() async -> Carried? {
            fetches += 1
            return stored
        }

        func put(_ carried: Carried) async {
            puts += 1
            stored = carried
        }

        func forget() async {
            forgets += 1
            stored = nil
        }
    }

    /// The session builds a real one otherwise, which would talk to the phone's
    /// notification centre from a test.
    @MainActor
    private final class QuietRinger: Ringer {
        func ask() async -> Bool { true }
        func ring(at times: [Date]) {}
        func silence() {}
    }

    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let morning = Date(timeIntervalSince1970: 1_800_000_000)
    private var today: DayKey { DayKey(morning) }

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
        let store: MemoryStore
        let cloud: FakeCloud
        let session: QuietSession
    }

    private func makeWorld(
        limit: Int = 20,
        usedHere: TimeInterval = 0,
        carrying: Bool = true,
        phone: String = "here"
    ) -> World {
        let store = MemoryStore()
        var ledger = UsageLedger(day: today, endsAt: today.end())
        ledger.add(usedHere)
        store.save(today, for: .setupDay)
        store.save(LimitState(minutes: limit), for: .limit)
        store.save(ledger, for: .usage)

        let suite = "quiet.tests.\(UUID().uuidString)"
        suites.append(suite)
        let preferences = Preferences(defaults: UserDefaults(suiteName: suite)!)
        preferences.carriesBetweenDevices = carrying

        let cloud = FakeCloud()
        let session = QuietSession(
            store: store,
            clock: MonotonicClock(base: FakeTime(morning), store: store, uptime: { 10_000 }),
            preferences: preferences,
            ringer: QuietRinger(),
            cloud: cloud,
            phone: phone
        )
        return World(store: store, cloud: cloud, session: session)
    }

    /// What the other phone would have left up there.
    private func fromElsewhere(
        version: Int = 1,
        minutes: Int = 20,
        pending: PendingChange? = nil,
        lastIncrease: DayKey? = nil,
        cooldown: Int? = nil,
        spent: TimeInterval,
        as name: String = "there"
    ) -> Carried {
        Carried(
            version: version,
            limit: LimitState(
                minutes: minutes,
                pending: pending,
                lastIncrease: lastIncrease,
                cooldown: cooldown
            ),
            day: today,
            byDevice: [name: spent]
        )
    }

    func testNothingIsSentUntilSomebodyAsks() async {
        let world = makeWorld(usedHere: 300, carrying: false)
        world.session.start()
        await world.session.catchUp()

        XCTAssertEqual(world.cloud.fetches, 0)
        XCTAssertEqual(world.cloud.puts, 0)
        XCTAssertNil(world.cloud.stored)
    }

    func testThisPhonePublishesItsOwnFigureUnderItsOwnName() async {
        let world = makeWorld(usedHere: 300)
        world.session.start()
        await world.session.catchUp()

        XCTAssertEqual(world.cloud.stored?.byDevice, ["here": 300])
    }

    /// The reason the feature exists. Twenty minutes a day and two phones is
    /// forty minutes, unless the two of them are counted together.
    func testASecondDeviceIsNotASecondAllowance() async {
        let world = makeWorld(limit: 20, usedHere: 300)
        world.session.start()
        world.cloud.stored = fromElsewhere(spent: 900)

        await world.session.catchUp()

        XCTAssertEqual(world.session.remaining, 0, "five minutes here and fifteen there is the whole day")
        XCTAssertEqual(world.session.screen, .spent, "and the curtain comes down on this phone too")
    }

    func testTheOtherPhonesFigureIsNotCountedTwice() async {
        let world = makeWorld(limit: 60, usedHere: 300)
        world.session.start()
        world.cloud.stored = fromElsewhere(minutes: 60, spent: 600)

        await world.session.catchUp()
        await world.session.catchUp()
        await world.session.catchUp()

        XCTAssertEqual(world.session.remaining, 60 * 60 - 900)
    }

    func testALimitRaisedOnTheOtherPhoneIsAdopted() async {
        let world = makeWorld(limit: 20)
        world.session.start()
        world.cloud.stored = fromElsewhere(version: 9, minutes: 45, spent: 0)

        await world.session.catchUp()

        XCTAssertEqual(world.session.limit.minutes, 45)
    }

    /// The door the merge closes, seen from the app: a phone that has never
    /// raised anything cannot wipe the weekly clock the other one is holding.
    func testTheWeeklyClockSurvivesTheOtherPhone() async {
        let world = makeWorld(limit: 20)
        world.session.start()
        world.cloud.stored = fromElsewhere(version: 9, minutes: 20, lastIncrease: today, spent: 0)

        await world.session.catchUp()

        XCTAssertEqual(world.session.limit.lastIncrease, today)
        if case .success = world.session.requestLimit(45) {
            XCTFail("an increase should still be inside the week the other phone started")
        }
    }

    func testAskingForLessIsPutUpForTheOtherPhone() async {
        let world = makeWorld(limit: 30)
        world.session.start()
        await world.session.catchUp()

        world.session.requestLimit(10)
        await world.session.catchUp()

        XCTAssertEqual(world.cloud.stored?.limit.minutes, 10)
        XCTAssertGreaterThan(world.cloud.stored?.version ?? 0, 0, "a local change says it came later")
    }

    func testSwitchingItOffTakesTheCopyDown() async {
        let world = makeWorld(usedHere: 300)
        world.session.start()
        await world.session.catchUp()
        XCTAssertNotNil(world.cloud.stored)

        world.session.carryBetweenDevices(false)
        // The switch starts the work and does not wait for it, so the test has
        // to give the main actor a few turns before asking what happened.
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(world.cloud.forgets, 1)
        XCTAssertNil(world.cloud.stored)
    }

    /// Nothing is written that says what the record already says.
    func testAnUnchangedAgreementIsNotWrittenBack() async {
        let world = makeWorld(usedHere: 300)
        world.session.start()
        await world.session.catchUp()
        let first = world.cloud.puts

        await world.session.catchUp()

        XCTAssertEqual(world.cloud.puts, first)
    }
}
