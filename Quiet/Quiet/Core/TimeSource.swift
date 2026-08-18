import Foundation

/// The source of "now".
///
/// A protocol rather than a direct call to `Date()` so that the rules below can
/// be tested at speed, and so the guarded clock can wrap the system one. Named
/// `TimeSource` rather than `Clock` to stay out of the standard library's way.
protocol TimeSource: AnyObject {
    var now: Date { get }
}

final class SystemTimeSource: TimeSource {
    var now: Date { Date() }
}

/// Wall-clock time that is not allowed to move backwards.
///
/// Setting the device clock back is the cheapest way to defeat a rule that says
/// "once a week". `MonotonicClock` remembers the furthest point in time it has
/// ever seen and refuses to report anything earlier, so a rewind buys nothing:
/// time simply stops until the real clock catches up.
///
/// A jump *forward* cannot be detected without a server, and Quiet has no
/// server. That trade is stated plainly in the app's About screen rather than
/// hidden.
final class MonotonicClock: TimeSource {
    private let base: any TimeSource
    private let store: any HighWaterMarkStore

    /// Only persist once the mark has moved by this much, so that reading the
    /// time does not mean writing to the keychain several times a second.
    private static let persistGranularity: TimeInterval = 60

    private var mark: Date
    private var persistedMark: Date

    init(base: any TimeSource = SystemTimeSource(), store: any HighWaterMarkStore) {
        self.base = base
        self.store = store
        let recorded = store.highWaterMark ?? base.now
        mark = recorded
        persistedMark = recorded
        if store.highWaterMark == nil {
            // Write the baseline straight away. Without it, a first run that is
            // killed before any flush leaves nothing behind, and a rewind before
            // the next launch would go unnoticed.
            store.highWaterMark = recorded
        }
    }

    var now: Date {
        let actual = base.now
        if actual > mark {
            mark = actual
            if actual.timeIntervalSince(persistedMark) >= Self.persistGranularity {
                persistedMark = actual
                store.highWaterMark = actual
            }
        }
        return mark
    }

    /// True when the device clock currently sits behind time Quiet has already
    /// seen — the signature of a rewind. Surfaced to the user, never silently
    /// worked around.
    var isRewound: Bool {
        base.now < mark.addingTimeInterval(-Self.persistGranularity)
    }

    /// Called when the app leaves the foreground, so the mark survives a kill.
    func flush() {
        guard mark > persistedMark else { return }
        persistedMark = mark
        store.highWaterMark = mark
    }
}

protocol HighWaterMarkStore: AnyObject {
    var highWaterMark: Date? { get set }
}
