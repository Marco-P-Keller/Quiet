import XCTest
@testable import Quiet

/// The scale the chart is drawn against, and the one rule that keeps a column
/// looking like a measurement: the days set it, and a reference line joins them
/// only if it is within reach.
final class ChartScaleTests: XCTestCase {
    private func minutes(_ count: Double) -> TimeInterval { count * 60 }

    /// What fraction of the chart the busiest column fills.
    private func tallest(days: [TimeInterval], references: [TimeInterval]) -> Double {
        let busiest = ChartScale.busiest(days)
        return busiest / ChartScale.ceiling(busiest: busiest, references: references)
    }

    // MARK: - The one that was reported

    /// Five hours a day claimed, half an hour allowed, a quarter of an hour
    /// actually spent. Scaled against the claim, every column was six points
    /// high on a chart a hundred and fifty points tall.
    func testADayFarAboveTheDataIsLeftOffAndDoesNotSetTheScale() {
        let days = [minutes(13), minutes(11), minutes(14)]
        let busiest = ChartScale.busiest(days)

        XCTAssertFalse(ChartScale.shows(minutes(300), whenBusiestIs: busiest))
        XCTAssertTrue(ChartScale.shows(minutes(30), whenBusiestIs: busiest), "the limit is still in reach")

        let ceiling = ChartScale.ceiling(busiest: busiest, references: [minutes(30), minutes(300)])
        XCTAssertEqual(ceiling, minutes(30) * ChartScale.headroom, accuracy: 1)
    }

    func testTheBusiestColumnIsNeverCrushed() {
        // Every shape of week, against references from sensible to absurd.
        for busyMinutes in [1.0, 5, 13, 40, 120, 240] {
            for reference in [5.0, 30, 75, 300, 480] {
                let filled = tallest(
                    days: [minutes(busyMinutes)],
                    references: [minutes(reference)]
                )
                XCTAssertGreaterThan(
                    filled,
                    0.36,
                    "\(busyMinutes) minutes against \(reference) filled only \(filled)"
                )
            }
        }
    }

    // MARK: - When a line does belong

    func testAReferenceWithinReachJoinsTheScale() {
        let days = [minutes(30)]
        let busiest = ChartScale.busiest(days)
        XCTAssertTrue(ChartScale.shows(minutes(60), whenBusiestIs: busiest))
        XCTAssertEqual(
            ChartScale.ceiling(busiest: busiest, references: [minutes(60)]),
            minutes(60) * ChartScale.headroom,
            accuracy: 1
        )
    }

    /// The common case, and the reason the rule is not simply "scale to the
    /// data": most days come in under the limit, and the limit is the line
    /// worth having.
    func testALimitAboveAQuietWeekIsStillDrawn() {
        let busiest = ChartScale.busiest([minutes(12)])
        XCTAssertTrue(ChartScale.shows(minutes(20), whenBusiestIs: busiest))
        XCTAssertTrue(ChartScale.shows(minutes(30), whenBusiestIs: busiest))
    }

    func testAReferenceUnderTheDataIsAlwaysDrawn() {
        let busiest = ChartScale.busiest([minutes(90)])
        XCTAssertTrue(ChartScale.shows(minutes(20), whenBusiestIs: busiest))
        XCTAssertEqual(
            ChartScale.ceiling(busiest: busiest, references: [minutes(20)]),
            minutes(90) * ChartScale.headroom,
            accuracy: 1,
            "a line below the data cannot raise the ceiling"
        )
    }

    func testNothingIsDrawnForAReferenceNobodyHasGiven() {
        XCTAssertFalse(ChartScale.shows(0, whenBusiestIs: minutes(10)))
    }

    // MARK: - Nothing to draw

    func testAChartWithNoDaysStillHasAScale() {
        let busiest = ChartScale.busiest([])
        XCTAssertEqual(busiest, ChartScale.leastBusy)
        XCTAssertGreaterThan(ChartScale.ceiling(busiest: busiest, references: []), 0)
    }

    func testASingleGlanceDoesNotMakeAScaleOutOfNothing() {
        XCTAssertEqual(ChartScale.busiest([5]), ChartScale.leastBusy)
    }

    func testTheTallestThingIsInsideTheChartRatherThanOnItsEdge() {
        let busiest = ChartScale.busiest([minutes(40)])
        XCTAssertGreaterThan(ChartScale.ceiling(busiest: busiest, references: []), busiest)
    }
}
