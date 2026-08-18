import XCTest
@testable import Quiet

/// Turning the date back is the cheapest attack on a weekly rule, so it gets a
/// test of its own.
final class MonotonicClockTests: XCTestCase {
    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testFollowsTheDeviceClockForwards() {
        let base = FakeTime(start)
        let clock = MonotonicClock(base: base, store: MemoryStore())

        base.now = start.addingTimeInterval(3600)
        XCTAssertEqual(clock.now, start.addingTimeInterval(3600))
    }

    func testRefusesToGoBackwards() {
        let base = FakeTime(start)
        let clock = MonotonicClock(base: base, store: MemoryStore())
        _ = clock.now

        base.now = start.addingTimeInterval(-86_400 * 30)
        XCTAssertEqual(clock.now, start, "a month of rewind buys nothing")
        XCTAssertTrue(clock.isRewound)
    }

    func testResumesOnceTheDeviceClockCatchesUp() {
        let base = FakeTime(start)
        let clock = MonotonicClock(base: base, store: MemoryStore())
        base.now = start.addingTimeInterval(7200)
        _ = clock.now

        base.now = start
        XCTAssertEqual(clock.now, start.addingTimeInterval(7200))
        XCTAssertTrue(clock.isRewound)

        base.now = start.addingTimeInterval(10_000)
        XCTAssertEqual(clock.now, start.addingTimeInterval(10_000))
        XCTAssertFalse(clock.isRewound)
    }

    func testTheMarkSurvivesARestart() {
        let store = MemoryStore()
        let base = FakeTime(start)
        let first = MonotonicClock(base: base, store: store)
        base.now = start.addingTimeInterval(86_400)
        _ = first.now
        first.flush()

        let rewound = FakeTime(start.addingTimeInterval(-86_400))
        let second = MonotonicClock(base: rewound, store: store)
        XCTAssertEqual(second.now, start.addingTimeInterval(86_400), "a relaunch does not forget")
    }

    /// Reading the time must not mean writing to the keychain several times a
    /// second, so small advances are only persisted once they add up.
    func testSmallAdvancesAreNotWrittenOutImmediately() {
        let store = MemoryStore()
        let base = FakeTime(start)
        let clock = MonotonicClock(base: base, store: store)

        base.now = start.addingTimeInterval(5)
        _ = clock.now
        XCTAssertEqual(store.highWaterMark, start)

        clock.flush()
        XCTAssertEqual(store.highWaterMark, start.addingTimeInterval(5))
    }
}
