import XCTest
@testable import Quiet

/// The days behind you, and the one rule that keeps the number honest: a day
/// Quiet was not opened on counts for nothing, in either direction.
final class HistoryTests: XCTestCase {
    private let day = DayKey(ordinal: 500)

    /// Days as offsets from `day`, and totals in whole seconds — integers, so
    /// that a list of them written inline stays a list of numbers rather than a
    /// cast.
    private func history(_ pairs: [(Int, Int)]) -> History {
        var history = History()
        for (offset, seconds) in pairs {
            history.record(day.adding(days: offset), seconds: TimeInterval(seconds))
        }
        return history
    }

    func testRecordingKeepsDaysInOrder() {
        let history = history([(2, 60), (0, 120), (1, 180)])
        XCTAssertEqual(history.days.map(\.day), [day, day.adding(days: 1), day.adding(days: 2)])
        XCTAssertEqual(history.days.map(\.seconds), [120, 180, 60])
    }

    func testRecordingTheSameDayTwiceReplacesIt() {
        var history = history([(0, 120)])
        history.record(day, seconds: 300)
        XCTAssertEqual(history.days.count, 1)
        XCTAssertEqual(history.seconds(on: day), 300)
    }

    func testADayNobodyWroteDownIsNotZero() {
        let history = history([(0, 120)])
        XCTAssertNil(history.seconds(on: day.adding(days: 1)), "absent is not the same as empty")
    }

    func testOldestDaysFallOffTheEnd() {
        var history = History()
        for offset in 0..<(History.horizon + 10) {
            history.record(day.adding(days: offset), seconds: 60)
        }
        XCTAssertEqual(history.days.count, History.horizon)
        XCTAssertEqual(history.days.first?.day, day.adding(days: 10))
    }

    // MARK: - What was saved

    func testSavingIsMeasuredPerDayAgainstTheBaseline() {
        // Sixty a day claimed; twenty and thirty spent.
        let history = history([(0, 20 * 60), (1, 30 * 60)])
        XCTAssertEqual(history.saved(against: 60), 70 * 60)
    }

    /// The one that a single subtraction across the window gets wrong.
    func testADayOverTheOldAverageDoesNotEatTheDaysAroundIt() {
        // Two quiet days and one enormous one. Floored per day, the big day
        // contributes nothing; subtracted in bulk it would wipe out both others.
        let history = history([(0, 10 * 60), (1, 200 * 60), (2, 10 * 60)])
        XCTAssertEqual(history.saved(against: 60), 100 * 60)
    }

    func testUnrecordedDaysSaveNothing() {
        // Opened on one day of a week. The other six are not six hours rescued;
        // they are six days Quiet knows nothing about.
        let history = history([(0, 10 * 60)])
        let week = day...day.adding(days: 6)
        XCTAssertEqual(history.saved(against: 60, in: week), 50 * 60)
        XCTAssertEqual(history.spent(in: week), 10 * 60)
    }

    func testSavingIsNothingWhenNothingWasSaid() {
        let history = history([(0, 10 * 60)])
        XCTAssertEqual(history.saved(against: 0), 0)
    }

    // MARK: - The chart

    func testARunFillsInTheDaysThatAreMissing() {
        let history = history([(0, 60), (2, 120)])
        let run = history.run(endingOn: day.adding(days: 2), length: 3)
        XCTAssertEqual(run.map(\.day), [day, day.adding(days: 1), day.adding(days: 2)])
        XCTAssertEqual(run.map(\.seconds), [60, nil, 120])
    }

    func testARunEndsOnTheDayItWasAskedFor() {
        let run = history([(0, 60)]).run(endingOn: day.adding(days: 10), length: 2)
        XCTAssertEqual(run.map(\.day), [day.adding(days: 9), day.adding(days: 10)])
        XCTAssertEqual(run.compactMap(\.seconds), [])
    }

    func testHistorySurvivesBeingWrittenDown() throws {
        let history = history([(0, 60), (3, 120)])
        let data = try JSONEncoder().encode(history)
        XCTAssertEqual(try JSONDecoder().decode(History.self, from: data), history)
    }
}
