import XCTest
@testable import Quiet

final class UsageLedgerTests: XCTestCase {
    private let day = DayKey(ordinal: 500)

    func testAccumulatesForegroundTime() {
        var ledger = UsageLedger(day: day)
        ledger.add(30)
        ledger.add(30)
        XCTAssertEqual(ledger.seconds, 60)
        XCTAssertEqual(ledger.remaining(limitMinutes: 20), 19 * 60)
    }

    func testIgnoresNonsenseIntervals() {
        var ledger = UsageLedger(day: day)
        ledger.add(-500)
        ledger.add(0)
        ledger.add(UsageLedger.plausibleTick + 1)
        XCTAssertEqual(ledger.seconds, 0, "a clock jump is not time on a screen")
    }

    func testRollingToANewDayStartsFromNothing() {
        var ledger = UsageLedger(day: day)
        ledger.add(600)
        ledger.roll(to: day.next)
        XCTAssertEqual(ledger.day, day.next)
        XCTAssertEqual(ledger.seconds, 0)
    }

    func testRollingToTheSameDayKeepsTheTotal() {
        var ledger = UsageLedger(day: day)
        ledger.add(600)
        ledger.roll(to: day)
        XCTAssertEqual(ledger.seconds, 600)
    }

    func testRemainingNeverGoesNegative() {
        var ledger = UsageLedger(day: day)
        ledger.add(3000)
        XCTAssertEqual(ledger.remaining(limitMinutes: 20), 0)
        XCTAssertTrue(ledger.isSpent(limitMinutes: 20))
    }

    func testLoweringTheLimitCanSpendTheDayThatIsAlreadyRunning() {
        var ledger = UsageLedger(day: day)
        ledger.add(11 * 60)
        XCTAssertFalse(ledger.isSpent(limitMinutes: 20))
        XCTAssertTrue(ledger.isSpent(limitMinutes: 10))
    }

    func testRoundTripsThroughCoding() throws {
        var ledger = UsageLedger(day: day)
        ledger.add(123)
        let data = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(UsageLedger.self, from: data), ledger)
    }
}
