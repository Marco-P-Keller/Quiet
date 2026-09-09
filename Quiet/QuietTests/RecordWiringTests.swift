import XCTest
@testable import Quiet

/// The rules themselves are pinned in `HistoryTests` and `RecapTests`. This is
/// the wiring: that a day which ends is actually written down before the ledger
/// forgets it, that the total the screen shows is the two halves added up, and
/// that being forgotten forgets this too.
@MainActor
final class RecordWiringTests: XCTestCase {
    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    /// The session builds a real one otherwise, which would talk to the phone's
    /// notification centre from a test.
    @MainActor
    private final class SpyRinger: Ringer {
        var recaps: [Chime] = []
        var grants = true
        var asked = 0

        func ask() async -> Bool {
            asked += 1
            return grants
        }

        func ring(at times: [Date]) {}
        func chime(_ chimes: [Chime]) { recaps = chimes }
        func silence() { recaps = [] }
    }

    private final class NoCloud: Cloud {
        func fetch() async -> Carried? { nil }
        func put(_ carried: Carried) async {}
        func forget() async {}
    }

    /// A fixed zone, so that "the day turned" is a fact rather than a property
    /// of the machine running the tests.
    private let zurich: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }()

    private let noon = Date(timeIntervalSince1970: 1_800_000_000)
    private var today: DayKey { DayKey(noon, calendar: zurich) }

    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        suites = []
        super.tearDown()
    }

    private func makePreferences() -> Preferences {
        let suite = "quiet.tests.\(UUID().uuidString)"
        suites.append(suite)
        return Preferences(defaults: UserDefaults(suiteName: suite)!)
    }

    /// `nil` rather than a fresh spy as a default argument, for the reason the
    /// session's own initialiser writes down: a default is evaluated at the call
    /// site, which is not isolated, and `SpyRinger` belongs to the main actor.
    private func makeSession(
        store: MemoryStore,
        time: FakeTime,
        ringer: SpyRinger? = nil,
        preferences: Preferences? = nil
    ) -> QuietSession {
        QuietSession(
            store: store,
            clock: MonotonicClock(base: time, store: store),
            preferences: preferences ?? makePreferences(),
            calendar: zurich,
            ringer: ringer ?? SpyRinger(),
            cloud: NoCloud(),
            phone: "test"
        )
    }

    /// A phone that has been set up and has spent `used` seconds today.
    private func setUp(used: TimeInterval, baseline: Int = 60) -> (MemoryStore, FakeTime) {
        let store = MemoryStore()
        var ledger = UsageLedger(day: today, endsAt: today.end(calendar: zurich))
        ledger.add(used)
        store.save(today, for: .setupDay)
        store.save(LimitState(minutes: 20), for: .limit)
        store.save(ledger, for: .usage)
        store.save(baseline, for: .baseline)
        return (store, FakeTime(noon))
    }

    // MARK: - Setup

    func testSetupWritesDownTheDayYouStartedFrom() {
        let store = MemoryStore()
        let session = makeSession(store: store, time: FakeTime(noon))
        session.start()
        session.completeSetup(baseline: 90, limit: 20)

        XCTAssertEqual(session.baseline, 90)
        XCTAssertEqual(store.load(Int.self, for: .baseline), 90)
    }

    func testAnAbsurdBaselineIsBroughtBackInsideTheRange() {
        let store = MemoryStore()
        let session = makeSession(store: store, time: FakeTime(noon))
        session.start()
        session.completeSetup(baseline: 5_000, limit: 20)

        XCTAssertEqual(session.baseline, QuietSession.baselineCeiling)
    }

    func testAStoreFromBeforeThisQuestionExistedSaysNothing() {
        let (store, time) = setUp(used: 0)
        store.remove(.baseline)
        let session = makeSession(store: store, time: time)
        session.start()

        XCTAssertEqual(session.baseline, 0)
        XCTAssertEqual(session.savedSoFar, 0, "nothing to measure against is not a saving of nothing")
    }

    // MARK: - The day turning

    func testTheDayThatEndsIsWrittenDownBeforeTheLedgerForgetsIt() {
        let (store, time) = setUp(used: 12 * 60)
        let session = makeSession(store: store, time: time)
        session.start()
        XCTAssertEqual(session.history.days, [], "today is not a day behind you")

        // Tomorrow, past four in the morning.
        time.now = today.end(calendar: zurich).addingTimeInterval(60)
        session.setForeground(true)

        XCTAssertEqual(session.history.seconds(on: today), 12 * 60)
        XCTAssertEqual(session.ledger.seconds, 0, "and the new day starts from nothing")
        XCTAssertEqual(store.load(History.self, for: .history)?.seconds(on: today), 12 * 60)
    }

    func testTheDaysBehindYouSurviveARelaunch() {
        let (store, time) = setUp(used: 12 * 60)
        let first = makeSession(store: store, time: time)
        first.start()
        time.now = today.end(calendar: zurich).addingTimeInterval(60)
        first.setForeground(true)

        let second = makeSession(store: store, time: time)
        second.start()
        XCTAssertEqual(second.history.seconds(on: today), 12 * 60)
    }

    // MARK: - What the screen adds up

    func testTheRecordFoldsInTheDayThatIsStillRunning() {
        let (store, time) = setUp(used: 12 * 60)
        let session = makeSession(store: store, time: time)
        session.start()

        XCTAssertEqual(session.record.seconds(on: today), 12 * 60)
        XCTAssertNil(session.history.seconds(on: today), "but only in the reading, not in the record")
    }

    /// The headline number is allowed to be dull; it is not allowed to move
    /// backwards while somebody reads it.
    func testTheHeadlineTotalIgnoresTheDayStillRunning() {
        let (store, time) = setUp(used: 12 * 60)
        let session = makeSession(store: store, time: time)
        session.start()

        XCTAssertEqual(session.savedSoFar, 0)
        XCTAssertEqual(session.savedToday, 48 * 60, "which is where today's standing is said instead")

        time.now = today.end(calendar: zurich).addingTimeInterval(60)
        session.setForeground(true)
        XCTAssertEqual(session.savedSoFar, 48 * 60, "and it lands once the day has closed")
    }

    func testTheDayYouStartedFromCanBeCorrected() {
        let (store, time) = setUp(used: 12 * 60, baseline: 60)
        let session = makeSession(store: store, time: time)
        session.start()
        session.setBaseline(30)

        XCTAssertEqual(session.baseline, 30)
        XCTAssertEqual(session.savedToday, 18 * 60)
        XCTAssertEqual(store.load(Int.self, for: .baseline), 30)
    }

    // MARK: - The morning note

    /// The one preference in Quiet that is on to begin with, so the mornings
    /// are on the phone without anybody having gone looking for a switch.
    func testTheNoteIsOnWithoutBeingAskedFor() async {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        let session = makeSession(store: store, time: time, ringer: ringer)
        session.start()

        XCTAssertTrue(session.recap.isOn)
        XCTAssertFalse(ringer.recaps.isEmpty)
    }

    /// Being on is not the same as being allowed, and the difference is the
    /// whole reason the question gets put at all.
    func testAPhoneThatSaysNoTurnsTheSwitchBackOff() async {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        ringer.grants = false
        let preferences = makePreferences()
        let session = makeSession(store: store, time: time, ringer: ringer, preferences: preferences)
        session.start()
        await session.askAboutTheMorningNote()

        XCTAssertFalse(session.recap.isOn, "a switch standing over nothing would be a lie")
        XCTAssertEqual(ringer.recaps, [])
        XCTAssertTrue(preferences.hasAskedAboutRecap)
    }

    func testThePhoneIsOnlyEverAskedOnce() async {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        let preferences = makePreferences()
        let session = makeSession(store: store, time: time, ringer: ringer, preferences: preferences)
        session.start()
        await session.askAboutTheMorningNote()
        let asked = ringer.asked
        await session.askAboutTheMorningNote()

        XCTAssertEqual(ringer.asked, asked, "the grant lives with iOS, not here")
    }

    func testSwitchingTheNoteOnSchedulesTheMorningsItCanSpeakFor() async {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        let session = makeSession(store: store, time: time, ringer: ringer)
        session.start()
        session.turnOffRecap()
        await session.turnOnRecap()

        // Tomorrow's, which reports today, and then only the mornings whose
        // window still reaches back to a day Quiet has been open for — never a
        // full week of them off the back of a single day. See `RecapTests`.
        XCTAssertFalse(ringer.recaps.isEmpty)
        XCTAssertLessThan(ringer.recaps.count, Recap.horizon)
        XCTAssertTrue(ringer.recaps[0].body.contains(Phrase.span(12 * 60)), ringer.recaps[0].body)
    }

    func testSwitchingItOffTakesTheMorningsDownAgain() async {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        let session = makeSession(store: store, time: time, ringer: ringer)
        session.start()
        XCTAssertFalse(ringer.recaps.isEmpty)

        session.turnOffRecap()
        XCTAssertEqual(ringer.recaps, [])
    }

    func testTheNoteSaysNothingWhileThereIsNothingToMeasureAgainst() async {
        let (store, time) = setUp(used: 12 * 60, baseline: 0)
        store.remove(.baseline)
        let ringer = SpyRinger()
        let session = makeSession(store: store, time: time, ringer: ringer)
        session.start()

        XCTAssertEqual(ringer.recaps, [])
    }

    /// The last chance to fix a sentence that will be read tomorrow morning.
    func testGoingToTheBackgroundRewritesTheMorningsWithWhatWasJustSpent() async {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        let session = makeSession(store: store, time: time, ringer: ringer)
        session.start()
        let before = ringer.recaps

        // A longer session, and then away.
        var ledger = UsageLedger(day: today, endsAt: today.end(calendar: zurich))
        ledger.add(18 * 60)
        store.save(ledger, for: .usage)
        let second = makeSession(store: store, time: time, ringer: ringer, preferences: session.preferences)
        second.start()
        second.setForeground(true)
        second.setForeground(false)

        XCTAssertNotEqual(ringer.recaps, before)
        XCTAssertTrue(ringer.recaps[0].body.contains(Phrase.span(18 * 60)), ringer.recaps[0].body)
    }

    // MARK: - Letting go

    func testBeingForgottenForgetsTheDaysBehindYouToo() {
        let (store, time) = setUp(used: 12 * 60)
        let ringer = SpyRinger()
        let preferences = makePreferences()
        let session = makeSession(store: store, time: time, ringer: ringer, preferences: preferences)
        session.start()
        // Close a day, so there is something to throw away.
        time.now = today.end(calendar: zurich).addingTimeInterval(60)
        session.setForeground(true)
        XCTAssertFalse(session.history.days.isEmpty)

        let day = session.askToBeForgotten()
        time.now = day.start(calendar: zurich).addingTimeInterval(3600)
        let after = makeSession(store: store, time: time, ringer: ringer, preferences: preferences)
        after.start()

        XCTAssertEqual(after.screen, .setup)
        XCTAssertEqual(after.baseline, 0)
        XCTAssertEqual(after.history.days, [])
        XCTAssertNil(store.load(History.self, for: .history))
        XCTAssertNil(store.load(Int.self, for: .baseline))
        // Back to the state a phone that has never run this app is in, which
        // includes the morning note being on and the question not yet put.
        XCTAssertTrue(preferences.recap.isOn)
        XCTAssertFalse(preferences.hasAskedAboutRecap)
    }
}
