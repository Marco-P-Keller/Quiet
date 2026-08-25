import XCTest
@testable import Quiet

/// What the app says about its own memory, and when it stops saying it.
///
/// The banner behind these tests is not decoration. Quiet's whole promise is
/// that the limit outlives the app, and a store that refuses writes while
/// looking healthy turns that into the opposite promise. What was missing was
/// the other direction: the refusal that actually happens on a phone is a
/// device still locked after a restart, which declines every write and then
/// accepts every write a passcode later.
@MainActor
final class MemoryHealthTests: XCTestCase {
    /// A store that can be told to turn writes down, one key at a time.
    private final class FlakyStore: StateStore, HighWaterMarkStore {
        private var values: [StoreKey: Data] = [:]
        private var unwritten: Set<StoreKey> = []

        /// Keys this store will refuse until told otherwise.
        var refusing: Set<StoreKey> = []

        var isWritable: Bool { unwritten.isEmpty }

        func load<T: Codable>(_ type: T.Type, for key: StoreKey) -> T? {
            guard let data = values[key] else { return nil }
            return try? JSONDecoder().decode(Boxed<T>.self, from: data).value
        }

        func save<T: Codable>(_ value: T, for key: StoreKey) {
            guard !refusing.contains(key) else {
                unwritten.insert(key)
                return
            }
            values[key] = try? JSONEncoder().encode(Boxed(value: value))
            unwritten.remove(key)
        }

        func remove(_ key: StoreKey) { values[key] = nil }

        var highWaterMark: Date? {
            get { storedHighWaterMark }
            set { storedHighWaterMark = newValue }
        }
    }

    private final class FixedTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let noon = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(on store: FlakyStore) -> QuietSession {
        let day = DayKey(noon)
        store.save(day, for: .setupDay)
        store.save(LimitState(minutes: 20), for: .limit)
        store.save(UsageLedger(day: day, endsAt: day.end()), for: .usage)
        let clock = MonotonicClock(base: FixedTime(noon), store: store)
        let session = QuietSession(store: store, clock: clock)
        session.start()
        return session
    }

    func testARefusedWriteIsSaidOutLoud() {
        let store = FlakyStore()
        let session = session(on: store)
        XCTAssertTrue(session.isMemoryReliable)

        store.refusing = [.limit]
        _ = session.requestLimit(10)

        XCTAssertFalse(store.isWritable)
        XCTAssertFalse(
            session.isMemoryReliable,
            "A limit that was not written down must not be presented as kept."
        )
    }

    /// The case the old rule could not express. One refusal used to be final
    /// for the rest of the launch, so a phone that was merely locked wore the
    /// banner until it was killed and started again.
    func testMemoryComesBackWhenTheStoreDoes() {
        let store = FlakyStore()
        let session = session(on: store)

        store.refusing = [.limit]
        _ = session.requestLimit(10)
        XCTAssertFalse(session.isMemoryReliable)

        store.refusing = []
        _ = session.requestLimit(9)

        XCTAssertTrue(store.isWritable)
        XCTAssertTrue(
            session.isMemoryReliable,
            "A value that has since been written down is written down."
        )
    }

    /// Health is a question about values, not about the app. A store that
    /// refuses one key and accepts another is still a store with something
    /// missing, and saying otherwise would take the banner down over a limit
    /// that is not there.
    func testWritingSomethingElseDoesNotClearTheWarning() {
        let store = FlakyStore()
        let session = session(on: store)

        store.refusing = [.limit]
        _ = session.requestLimit(10)
        XCTAssertFalse(session.isMemoryReliable)

        // Time passing writes the ledger, which is a different key.
        session.checkpoint()

        XCTAssertFalse(
            session.isMemoryReliable,
            "The limit is still unwritten, whatever else has been saved since."
        )
    }
}
