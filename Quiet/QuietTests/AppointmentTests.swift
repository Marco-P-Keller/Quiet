import XCTest
@testable import Quiet

/// The reminder is the one thing in Quiet that speaks first, so the rule about
/// when it stays quiet is worth pinning down in a fixed time zone.
final class AppointmentTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        self.calendar = calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute
        ).date!
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Appointment {
        Appointment(isOn: true, minutesAfterMidnight: hour * 60 + minute)
    }

    func testAnAppointmentThatIsOffNeverRings() {
        let off = Appointment(isOn: false, minutesAfterMidnight: 18 * 60)
        XCTAssertEqual(
            off.rings(after: date(2026, 6, 1, 9), openedToday: false, calendar: calendar),
            []
        )
    }

    func testTodaysHourComesFirstWhenItIsStillAhead() {
        let rings = at(18).rings(
            after: date(2026, 6, 1, 9),
            openedToday: false,
            calendar: calendar
        )
        XCTAssertEqual(rings.first, date(2026, 6, 1, 18))
    }

    func testAnHourThatHasPassedIsNotRungTodayAgain() {
        let rings = at(18).rings(
            after: date(2026, 6, 1, 19),
            openedToday: false,
            calendar: calendar
        )
        XCTAssertEqual(rings.first, date(2026, 6, 2, 18), "the next one is tomorrow")
    }

    /// The whole of the rule. A reminder that the window is open is worth
    /// having; the same reminder after you have been through it is an
    /// invitation to a second visit.
    func testADayAlreadySpentIsNotRungOn() {
        let rings = at(18).rings(
            after: date(2026, 6, 1, 9),
            openedToday: true,
            calendar: calendar
        )
        XCTAssertEqual(rings.first, date(2026, 6, 2, 18))
    }

    func testTomorrowIsStillRungOnAfterADaySpent() {
        let rings = at(18).rings(
            after: date(2026, 6, 1, 9),
            openedToday: true,
            calendar: calendar
        )
        XCTAssertEqual(rings.count, Appointment.horizon, "a full week is always put on the phone")
        XCTAssertEqual(rings.last, date(2026, 6, 8, 18))
    }

    func testAWeekIsScheduledAtOnce() {
        let rings = at(18).rings(
            after: date(2026, 6, 1, 9),
            openedToday: false,
            calendar: calendar
        )
        XCTAssertEqual(rings.count, Appointment.horizon)
        XCTAssertEqual(rings.first, date(2026, 6, 1, 18))
        XCTAssertEqual(rings.last, date(2026, 6, 7, 18))
    }

    func testTheRingsAreInOrderAndOneDayApart() {
        let rings = at(7, 30).rings(
            after: date(2026, 6, 1, 9),
            openedToday: false,
            calendar: calendar
        )
        XCTAssertEqual(rings, rings.sorted())
        for (earlier, later) in zip(rings, rings.dropFirst()) {
            XCTAssertEqual(
                calendar.dateComponents([.day], from: earlier, to: later).day, 1
            )
        }
    }

    /// An appointment after midnight belongs to the evening you are still awake
    /// in, because that is the day the ledger is counting. Set at two in the
    /// morning and read at eleven the night before, the next ring is the one a
    /// few hours away — and it is dropped if that evening has been spent.
    func testAnHourAfterMidnightBelongsToTheEveningBefore() {
        let evening = date(2026, 6, 1, 23)
        let unspent = at(2).rings(after: evening, openedToday: false, calendar: calendar)
        XCTAssertEqual(unspent.first, date(2026, 6, 2, 2))

        let spent = at(2).rings(after: evening, openedToday: true, calendar: calendar)
        XCTAssertEqual(
            spent.first,
            date(2026, 6, 3, 2),
            "two in the morning is still tonight, and tonight has been spent"
        )
    }

    /// The clocks go forward in Zurich at 02:00 on 29 March 2026, so 02:30 does
    /// not exist that morning. A reminder set for it must still land somewhere
    /// sensible rather than vanishing or arriving yesterday.
    func testTheMorningTheClocksGoForward() {
        let rings = at(2, 30).rings(
            after: date(2026, 3, 28, 12),
            openedToday: false,
            calendar: calendar
        )
        XCTAssertEqual(rings.count, Appointment.horizon)
        XCTAssertEqual(rings, rings.sorted())
        for ring in rings {
            XCTAssertGreaterThan(ring, date(2026, 3, 28, 12))
        }
    }
}
