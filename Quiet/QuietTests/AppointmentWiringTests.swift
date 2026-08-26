import XCTest
@testable import Quiet

/// The rule itself is pinned in `AppointmentTests`. This is the wiring: that
/// the session asks for the right days at the right moments, and that it asks
/// for none at all when there is nothing to remind anybody about.
@MainActor
final class AppointmentWiringTests: XCTestCase {
    /// Stands in for the phone's notification centre.
    ///
    /// Isolated explicitly: a type nested inside a main-actor class does not
    /// inherit that isolation, and `Ringer` is a main-actor protocol.
    @MainActor
    private final class SpyRinger: Ringer {
        var grants = true
        var asked = 0
        var pending: [Date] = []
        var silenced = 0

        func ask() async -> Bool {
            asked += 1
            return grants
        }

        func ring(at times: [Date]) {
            pending = times
        }

        func silence() {
            silenced += 1
            pending = []
        }
    }

    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    /// A fixed calendar throughout, so that "is nine in the evening still ahead
    /// of us" is a fact rather than a property of whichever machine is running
    /// the tests.
    private let zurich: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }()

    private let morning = Date(timeIntervalSince1970: 1_800_000_000)
    private var today: DayKey { DayKey(morning, calendar: zurich) }

    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        suites = []
        super.tearDown()
    }

    private func makePreferences(appointment: Appointment) -> Preferences {
        let suite = "quiet.tests.\(UUID().uuidString)"
        suites.append(suite)
        let preferences = Preferences(defaults: UserDefaults(suiteName: suite)!)
        preferences.appointment = appointment
        return preferences
    }

    /// A session that has been set up, with `used` seconds already spent today.
    private func makeSession(
        appointment: Appointment,
        setUp: Bool = true,
        used: TimeInterval = 0,
        ringer: SpyRinger
    ) -> QuietSession {
        let store = MemoryStore()
        if setUp {
            var ledger = UsageLedger(day: today, endsAt: today.end(calendar: zurich))
            ledger.add(used)
            store.save(today, for: .setupDay)
            store.save(LimitState(minutes: 20), for: .limit)
            store.save(ledger, for: .usage)
        }
        let time = FakeTime(morning)
        return QuietSession(
            store: store,
            clock: MonotonicClock(base: time, store: store, uptime: { 10_000 }),
            preferences: makePreferences(appointment: appointment),
            calendar: zurich,
            ringer: ringer
        )
    }

    private func hourOf(_ date: Date) -> Int {
        zurich.component(.hour, from: date)
    }

    private func days(_ from: Date, _ to: Date) -> Int? {
        zurich.dateComponents([.day], from: from, to: to).day
    }

    func testAWeekIsPutOnThePhoneAtLaunch() {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()

        XCTAssertEqual(ringer.pending.count, Appointment.horizon)
        XCTAssertTrue(ringer.pending.allSatisfy { hourOf($0) == 21 })
    }

    /// The rule, seen from the session: a day with seconds on the ledger is a
    /// day that has been opened, and it is not rung on.
    func testADayAlreadyOpenedLosesItsRing() {
        let unspent = SpyRinger()
        makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            ringer: unspent
        ).start()

        let spent = SpyRinger()
        makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            used: 60,
            ringer: spent
        ).start()

        XCTAssertEqual(unspent.pending.count, Appointment.horizon)
        XCTAssertEqual(spent.pending.count, Appointment.horizon)
        XCTAssertEqual(
            days(unspent.pending[0], spent.pending[0]),
            1,
            "the first reminder moves a day later once today has been opened"
        )
    }

    func testAnAppointmentThatIsOffPutsNothingOnThePhone() {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: false, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()
        XCTAssertEqual(ringer.pending, [])
    }

    /// An app nobody has set up yet has no window to remind anybody about, and
    /// this is also the state a forgotten app returns to.
    func testBeforeSetupThePhoneIsLeftAlone() {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            setUp: false,
            ringer: ringer
        )
        session.start()
        XCTAssertEqual(ringer.pending, [])
    }

    func testTheSwitchStaysOffWhenThePhoneSaysNo() async {
        let ringer = SpyRinger()
        ringer.grants = false
        let session = makeSession(
            appointment: Appointment(isOn: false, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()

        let granted = await session.turnOnAppointment()

        XCTAssertFalse(granted)
        XCTAssertFalse(session.appointment.isOn, "a switch that slid across would promise a reminder that never comes")
        XCTAssertEqual(ringer.pending, [])
    }

    func testTurningItOnSchedulesTheWeek() async {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: false, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()

        let granted = await session.turnOnAppointment()

        XCTAssertTrue(granted)
        XCTAssertTrue(session.appointment.isOn)
        XCTAssertEqual(ringer.pending.count, Appointment.horizon)
    }

    func testTurningItOffTakesThemBackOffAgain() async {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()
        XCTAssertFalse(ringer.pending.isEmpty)

        session.turnOffAppointment()

        XCTAssertEqual(ringer.pending, [])
        XCTAssertFalse(session.appointment.isOn)
    }

    func testMovingTheHourRebuildsTheWeek() {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()

        session.moveAppointment(to: 7 * 60 + 30)

        XCTAssertEqual(ringer.pending.count, Appointment.horizon)
        XCTAssertTrue(ringer.pending.allSatisfy { hourOf($0) == 7 })
    }

    func testAnHourOutsideTheDayIsBroughtBackInside() {
        let ringer = SpyRinger()
        let session = makeSession(
            appointment: Appointment(isOn: true, minutesAfterMidnight: 21 * 60),
            ringer: ringer
        )
        session.start()

        session.moveAppointment(to: -30)

        XCTAssertEqual(session.appointment.minutesAfterMidnight, 1410, "half an hour before midnight")
    }
}
