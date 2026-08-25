import XCTest
@testable import Quiet

/// The door that was missing.
///
/// The limit lives in the keychain because it has to outlive the app being
/// deleted — that is the promise, and the setup screen says so plainly. The
/// consequence nobody wrote down is that there was no way out at all: the only
/// exit was for somebody to know a keychain exists and go and find it, which is
/// not an exit, it is a trap with documentation.
///
/// So the door opens, and it opens slowly, and it can be shut again for free.
@MainActor
final class ForgettingTests: XCTestCase {
    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let noon = Date(timeIntervalSince1970: 1_800_000_000)
    private var today: DayKey { DayKey(noon) }

    private struct World {
        let store: MemoryStore
        let time: FakeTime
        let session: QuietSession
    }

    private func makeWorld(cooldown: Int? = nil) -> World {
        let store = MemoryStore()
        store.save(today, for: .setupDay)
        store.save(LimitState(minutes: 20, cooldown: cooldown), for: .limit)
        store.save(UsageLedger(day: today, endsAt: today.end()), for: .usage)
        let time = FakeTime(noon)
        let session = QuietSession(
            store: store,
            clock: MonotonicClock(base: time, store: store)
        )
        session.start()
        return World(store: store, time: time, session: session)
    }

    func testNothingHappensToday() {
        let world = makeWorld()
        let day = world.session.askToBeForgotten()

        XCTAssertEqual(day, today.adding(days: 7))
        XCTAssertEqual(world.session.screen, .browsing)
        XCTAssertEqual(world.session.limit.minutes, 20, "the limit is still the limit")
        XCTAssertNotNil(world.store.load(LimitState.self, for: .limit))
    }

    /// The wait is the wait currently in force, so somebody who asked to be
    /// held to a stricter rule is held to it here too — and cannot shorten this
    /// wait in the moment, because shortening that number is itself subject to
    /// it.
    func testTheWaitIsTheWaitInForce() {
        XCTAssertEqual(makeWorld(cooldown: 30).session.askToBeForgotten(), today.adding(days: 30))
    }

    /// A request that a reinstall could cancel would be a request that means
    /// nothing, so it lives where the limit lives.
    func testTheRequestOutlivesTheObjectThatMadeIt() {
        let world = makeWorld()
        world.session.askToBeForgotten()

        let second = QuietSession(
            store: world.store,
            clock: MonotonicClock(base: world.time, store: world.store)
        )
        second.start()
        XCTAssertEqual(second.forgetOn, today.adding(days: 7))
    }

    func testChangingYourMindIsFreeAndImmediate() {
        let world = makeWorld()
        world.session.askToBeForgotten()
        world.session.keepRemembering()

        XCTAssertNil(world.session.forgetOn)
        XCTAssertNil(world.store.load(DayKey.self, for: .forgetOn))

        // And the day it would have been forgotten comes and goes.
        world.time.now = noon.addingTimeInterval(30 * 24 * 3600)
        world.session.setForeground(true)
        defer { world.session.setForeground(false) }

        XCTAssertEqual(world.session.screen, .browsing)
        XCTAssertEqual(world.session.limit.minutes, 20)
    }

    /// The day comes, and what is left is an app that has never been run.
    func testWhenTheDayComesEverythingGoes() {
        let world = makeWorld()
        world.session.askToBeForgotten()

        world.time.now = noon.addingTimeInterval(7 * 24 * 3600)
        world.session.setForeground(true)
        defer { world.session.setForeground(false) }

        XCTAssertEqual(world.session.screen, .setup)
        XCTAssertNil(world.session.setupDay)
        XCTAssertNil(world.session.forgetOn)
        XCTAssertNil(world.store.load(LimitState.self, for: .limit))
        XCTAssertNil(world.store.load(UsageLedger.self, for: .usage))
        XCTAssertNil(world.store.load(DayKey.self, for: .setupDay))
        XCTAssertNil(world.store.load(DayKey.self, for: .forgetOn))
        XCTAssertNil(world.store.highWaterMark)
    }

    /// The beat between the screen changing and the ticker stopping used to be
    /// enough to write today's total straight back out on top of an app that
    /// had just been emptied.
    func testNothingIsWrittenBackAfterwards() {
        let world = makeWorld()
        world.session.askToBeForgotten()
        world.time.now = noon.addingTimeInterval(7 * 24 * 3600)
        world.session.setForeground(true)
        world.session.setForeground(false)

        XCTAssertNil(world.store.load(UsageLedger.self, for: .usage))
        XCTAssertNil(world.store.load(LimitState.self, for: .limit))
    }

    /// And a relaunch after the day has passed finds nothing rather than
    /// finding a limit and then throwing it away a moment later.
    func testALaunchOnTheDayFindsAFreshApp() {
        let world = makeWorld()
        world.session.askToBeForgotten()
        world.time.now = noon.addingTimeInterval(8 * 24 * 3600)

        let second = QuietSession(
            store: world.store,
            clock: MonotonicClock(base: world.time, store: world.store)
        )
        second.start()

        XCTAssertEqual(second.screen, .setup)
        XCTAssertNil(second.setupDay)
    }

    /// Asking again before the day simply moves the day, rather than stacking
    /// two requests nobody can see.
    func testAskingTwiceIsStillOneRequest() {
        let world = makeWorld()
        world.session.askToBeForgotten()
        world.time.now = noon.addingTimeInterval(2 * 24 * 3600)
        let second = world.session.askToBeForgotten()

        XCTAssertEqual(second, DayKey(world.time.now).adding(days: 7))
        XCTAssertEqual(world.session.forgetOn, second)
    }
}
