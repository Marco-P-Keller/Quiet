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
}

extension StateStore {
    /// Convenience for the clock, which thinks in dates rather than blobs.
    var storedHighWaterMark: Date? {
        get {
            load(Double.self, for: .highWaterMark).map(Date.init(timeIntervalSince1970:))
        }
        nonmutating set {
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
