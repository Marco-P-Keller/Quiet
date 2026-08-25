import Foundation

/// The four things Quiet remembers. There is no fifth.
enum StoreKey: String, CaseIterable, Sendable {
    /// The daily limit, plus any queued change.
    case limit
    /// Today's total.
    case usage
    /// The furthest point in time the app has seen.
    case highWaterMark
    /// The day setup finished. Its absence is what marks a fresh install, and
    /// its value is what lets the app know how new it still is to you.
    case setupDay
}

/// Somewhere to keep a handful of small values.
protocol StateStore: AnyObject {
    func load<T: Codable>(_ type: T.Type, for key: StoreKey) -> T?
    func save<T: Codable>(_ value: T, for key: StoreKey)
    func remove(_ key: StoreKey)

    /// False while any value the app has tried to write is not written down.
    ///
    /// Quiet's entire promise is that the limit outlives the app. A store that
    /// refuses writes and says nothing turns that into the opposite promise —
    /// every launch a clean slate — and it would look exactly like a working
    /// app. So the failure is carried out of here and said on screen.
    ///
    /// It comes back. The refusal that actually happens is a device still
    /// locked after a restart, which declines everything and then accepts
    /// everything a passcode later; a store that could only ever go from good
    /// to bad would leave the banner standing over a healthy keychain.
    var isWritable: Bool { get }
}

extension StateStore {
    /// Convenience for the clock, which thinks in dates rather than blobs.
    var storedHighWaterMark: Date? {
        get {
            load(Double.self, for: .highWaterMark).map(Date.init(timeIntervalSince1970:))
        }
        // No `nonmutating` here: the protocol is already class-bound, so the
        // setter never mutates anything, and Swift rejects the keyword outright.
        set {
            if let newValue {
                save(newValue.timeIntervalSince1970, for: .highWaterMark)
            } else {
                remove(.highWaterMark)
            }
        }
    }
}

/// A store that forgets everything when the process ends. Used by the tests, and
/// by SwiftUI previews.
final class MemoryStore: StateStore, HighWaterMarkStore {
    private var values: [StoreKey: Data] = [:]

    /// A dictionary never refuses.
    let isWritable = true

    init() {}

    func load<T: Codable>(_ type: T.Type, for key: StoreKey) -> T? {
        guard let data = values[key] else { return nil }
        return try? JSONDecoder().decode(Boxed<T>.self, from: data).value
    }

    func save<T: Codable>(_ value: T, for key: StoreKey) {
        values[key] = try? JSONEncoder().encode(Boxed(value: value))
    }

    func remove(_ key: StoreKey) {
        values[key] = nil
    }

    var highWaterMark: Date? {
        get { storedHighWaterMark }
        set { storedHighWaterMark = newValue }
    }
}

/// `JSONEncoder` refuses bare fragments on older platforms; a one-field wrapper
/// sidesteps the question for every type Quiet stores.
struct Boxed<Value>: Codable where Value: Codable {
    var value: Value
}

extension Boxed: Sendable where Value: Sendable {}
