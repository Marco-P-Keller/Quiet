import XCTest
@testable import Quiet

/// The day boundary is the quietest decision in the app and the easiest to get
/// wrong, so it is pinned here in a fixed time zone.
final class QuietDayTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        self.calendar = calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return components.date!
    }

    func testLateNightBelongsToTheEveningNotTheMorning() {
        let beforeMidnight = DayKey(date(2026, 3, 10, 23, 30), calendar: calendar)
        let afterMidnight = DayKey(date(2026, 3, 11, 1, 30), calendar: calendar)
        XCTAssertEqual(beforeMidnight, afterMidnight, "01:30 is still the same evening")
    }

    func testTheDayTurnsAtFourInTheMorning() {
        let justBefore = DayKey(date(2026, 3, 11, 3, 59), calendar: calendar)
        let justAfter = DayKey(date(2026, 3, 11, 4, 1), calendar: calendar)
        XCTAssertEqual(justBefore.next, justAfter)
    }

    func testConsecutiveDaysAreConsecutiveOrdinals() {
        let first = DayKey(date(2026, 6, 1, 12), calendar: calendar)
        let second = DayKey(date(2026, 6, 2, 12), calendar: calendar)
        XCTAssertEqual(first.days(to: second), 1)
        XCTAssertLessThan(first, second)
    }

    func testStartAndEndBracketTheDay() {
        let noon = date(2026, 6, 1, 12)
        let day = DayKey(noon, calendar: calendar)
        XCTAssertEqual(day.start(calendar: calendar), date(2026, 6, 1, 4))
        XCTAssertEqual(day.end(calendar: calendar), date(2026, 6, 2, 4))
        XCTAssertTrue(day.start(calendar: calendar) <= noon && noon < day.end(calendar: calendar))
    }

    /// Switzerland moves to summer time at 02:00 on 29 March 2026, inside the
    /// window Quiet counts as the previous day. The day must still be one day
    /// long as the calendar sees it, not 23 hours as arithmetic would have it.
    func testDaylightSavingDoesNotSkipOrRepeatADay() {
        let before = DayKey(date(2026, 3, 28, 12), calendar: calendar)
        let after = DayKey(date(2026, 3, 29, 12), calendar: calendar)
        XCTAssertEqual(before.days(to: after), 1)
        XCTAssertEqual(after.start(calendar: calendar), date(2026, 3, 29, 4))
    }

    func testSevenDaysLater() {
        let day = DayKey(date(2026, 6, 1, 12), calendar: calendar)
        let later = day.adding(days: 7)
        XCTAssertEqual(later.start(calendar: calendar), date(2026, 6, 8, 4))
    }

    func testRoundTripsThroughCoding() throws {
        let day = DayKey(date(2026, 6, 1, 12), calendar: calendar)
        let data = try JSONEncoder().encode(day)
        XCTAssertEqual(try JSONDecoder().decode(DayKey.self, from: data), day)
    }
}
