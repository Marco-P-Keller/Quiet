import XCTest
@testable import Quiet

/// The morning note speaks first and carries a sentence fixed days in advance,
/// so both halves of the rule are worth pinning down in a fixed time zone: which
/// window a given morning reports on, and when it says nothing at all.
final class RecapTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        // Monday, so the weekly recap lands where this test says it does. The
        // default for a Swiss locale is Monday anyway; saying it makes the test
        // independent of whichever machine runs it.
        calendar.firstWeekday = 2
        self.calendar = calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute
        ).date!
    }

    /// The Quiet day that the given calendar date belongs to, taken at noon so
    /// the four o'clock boundary is never in question.
    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> DayKey {
        DayKey(date(year, month, dayOfMonth, 12), calendar: calendar)
    }

    private func at(_ hour: Int) -> Recap {
        Recap(isOn: true, minutesAfterMidnight: hour * 60)
    }

    // MARK: - Which window a morning reports on

    /// Wednesday 10 September 2025. The day that closed is Tuesday the 9th, and
    /// it is neither the end of a week nor of a month.
    func testAnOrdinaryMorningReportsTheDayThatJustEnded() {
        let closed = day(2025, 9, 9)
        XCTAssertEqual(Recap.span(closing: closed, calendar: calendar), .day)
        XCTAssertEqual(Recap.window(for: .day, closing: closed, calendar: calendar), closed...closed)
    }

    /// Monday 8 September. The day that closed is Sunday the 7th, which is the
    /// last day of a week that starts on Monday.
    func testAMondayReportsTheWeek() {
        let closed = day(2025, 9, 7)
        XCTAssertEqual(Recap.span(closing: closed, calendar: calendar), .week)
        XCTAssertEqual(
            Recap.window(for: .week, closing: closed, calendar: calendar),
            day(2025, 9, 1)...closed
        )
    }

    /// The first of the month beats the week. 1 September 2025 was itself a
    /// Monday, and the day that closed — Sunday 31 August — closed both.
    func testTheEndOfAMonthWinsOverTheEndOfAWeek() {
        let closed = day(2025, 8, 31)
        XCTAssertEqual(Recap.span(closing: closed, calendar: calendar), .month)
        XCTAssertEqual(
            Recap.window(for: .month, closing: closed, calendar: calendar),
            day(2025, 8, 1)...closed
        )
    }

    /// The span is read off the day *after* the one closing, not off the hour
    /// the note happens to arrive at — which is the only version that survives
    /// somebody putting their recap before four in the morning.
    func testAPreDawnHourStillReportsTheRightWindow() {
        let record = full(from: day(2025, 9, 1), to: day(2025, 9, 7), minutes: 10)
        let chime = Recap.chime(
            at: date(2025, 9, 8, 2),
            record: record,
            baselineMinutes: 60,
            calendar: calendar
        )
        // Two in the morning on Monday the 8th still belongs to Sunday's Quiet
        // day, so the day that has closed is Saturday the 6th — an ordinary day,
        // not the week. The important half is that it is not nonsense.
        XCTAssertNotNil(chime)
        XCTAssertEqual(chime?.title, String(localized: "Yesterday"))
    }

    // MARK: - When it says nothing

    private func full(from: DayKey, to: DayKey, minutes: Int) -> History {
        var history = History()
        var day = from
        while day <= to {
            history.record(day, seconds: TimeInterval(minutes) * 60)
            day = day.next
        }
        return history
    }

    func testARecapThatIsOffNeverSpeaks() {
        let off = Recap(isOn: false, minutesAfterMidnight: 9 * 60)
        XCTAssertEqual(
            off.chimes(
                after: date(2025, 9, 9, 12),
                record: full(from: day(2025, 9, 1), to: day(2025, 9, 9), minutes: 10),
                baselineMinutes: 60,
                calendar: calendar
            ),
            []
        )
    }

    func testNothingIsSaidUntilSomebodyHasSaidWhatTheirDayWas() {
        XCTAssertEqual(
            at(9).chimes(
                after: date(2025, 9, 9, 12),
                record: full(from: day(2025, 9, 1), to: day(2025, 9, 9), minutes: 10),
                baselineMinutes: 0,
                calendar: calendar
            ),
            []
        )
    }

    /// The one that stops an abandoned app congratulating itself every morning
    /// for a week.
    func testMorningsAboutDaysQuietNeverSawAreSkipped() {
        var record = History()
        record.record(day(2025, 9, 9), seconds: 10 * 60)

        let chimes = at(9).chimes(
            after: date(2025, 9, 9, 22),
            record: record,
            baselineMinutes: 60,
            calendar: calendar
        )

        // The morning of the 10th reports the 9th and has something to say. The
        // four mornings after it would each be reporting a day with nothing
        // written down about it, and say nothing.
        XCTAssertEqual(chimes.first?.at, date(2025, 9, 10, 9))
        XCTAssertEqual(
            chimes.filter { $0.title == String(localized: "Yesterday") }.count,
            1,
            "one for the one day Quiet was open, and none for the days it was not"
        )
        XCTAssertLessThan(chimes.count, Recap.horizon)
    }

    /// The exception to the rule above, and it is the right one: a week that
    /// contains a day Quiet was open for is a week worth reporting, even when
    /// the six days either side of it are days Quiet knows nothing about. What
    /// it says of them is nothing — they add no time spent and no time saved.
    func testAWeekIsStillReportedWhenOnlyOneOfItsDaysWasSeen() throws {
        var record = History()
        record.record(day(2025, 9, 9), seconds: 10 * 60)

        let chimes = at(9).chimes(
            after: date(2025, 9, 9, 22),
            record: record,
            baselineMinutes: 60,
            calendar: calendar
        )

        let weekly = try XCTUnwrap(chimes.first { $0.title == String(localized: "Last week") })
        XCTAssertEqual(weekly.at, date(2025, 9, 15, 9), "the Monday after")
        XCTAssertTrue(weekly.body.contains(Phrase.span(10 * 60)), weekly.body)
        XCTAssertTrue(weekly.body.contains(Phrase.span(50 * 60)), "one day under, not seven")
    }

    func testAWeekOfUseGetsAWeekOfMornings() {
        let chimes = at(9).chimes(
            after: date(2025, 9, 9, 22),
            record: full(from: day(2025, 9, 1), to: day(2025, 9, 16), minutes: 10),
            baselineMinutes: 60,
            calendar: calendar
        )
        XCTAssertEqual(chimes.count, Recap.horizon)
        XCTAssertEqual(chimes.first?.at, date(2025, 9, 10, 9))
        XCTAssertEqual(chimes.map(\.id).count, Set(chimes.map(\.id)).count, "one note per morning")
    }

    func testAMorningAlreadyPastIsNotScheduled() {
        let chimes = at(9).chimes(
            after: date(2025, 9, 9, 12),
            record: full(from: day(2025, 9, 1), to: day(2025, 9, 16), minutes: 10),
            baselineMinutes: 60,
            calendar: calendar
        )
        XCTAssertEqual(chimes.first?.at, date(2025, 9, 10, 9), "not this morning, which has gone")
    }

    // MARK: - What it says

    func testTheSavingIsNamedWhenThereIsOne() throws {
        var record = History()
        record.record(day(2025, 9, 9), seconds: 10 * 60)
        let chime = try XCTUnwrap(Recap.chime(
            at: date(2025, 9, 10, 9),
            record: record,
            baselineMinutes: 60,
            calendar: calendar
        ))
        XCTAssertEqual(chime.title, String(localized: "Yesterday"))
        XCTAssertTrue(chime.body.contains(Phrase.span(10 * 60)), chime.body)
        XCTAssertTrue(chime.body.contains(Phrase.span(50 * 60)), chime.body)
    }

    /// A zero dressed up as an achievement is the register this app spends its
    /// whole time avoiding.
    func testADayOverTheOldOneIsReportedWithoutASaving() throws {
        var record = History()
        record.record(day(2025, 9, 9), seconds: 90 * 60)
        let chime = try XCTUnwrap(Recap.chime(
            at: date(2025, 9, 10, 9),
            record: record,
            baselineMinutes: 60,
            calendar: calendar
        ))
        XCTAssertEqual(chime.body, String(localized: "\(Phrase.span(90 * 60)) on Instagram."))
    }

    func testAWeeklyNoteCountsOnlyTheDaysQuietWasOpen() throws {
        var record = History()
        // Three days of a seven-day week.
        for offset in 0..<3 {
            record.record(day(2025, 9, 1).adding(days: offset), seconds: 10 * 60)
        }
        let chime = try XCTUnwrap(Recap.chime(
            at: date(2025, 9, 8, 9),
            record: record,
            baselineMinutes: 60,
            calendar: calendar
        ))
        XCTAssertEqual(chime.title, String(localized: "Last week"))
        XCTAssertTrue(chime.body.contains(Phrase.span(30 * 60)), chime.body)
        // Three days under by fifty minutes each, not seven.
        XCTAssertTrue(chime.body.contains(Phrase.span(150 * 60)), chime.body)
    }
}
