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

/// Wall-clock time that a settings screen cannot move.
///
/// Two attacks, and for a long time only one of them was answered.
///
/// **Backwards.** Setting the device clock back is the cheapest way to defeat a
/// rule that says "once a week". The clock remembers the furthest point in time
/// it has ever seen and refuses to report anything earlier, so a rewind buys
/// nothing: time simply stops until the real clock catches up.
///
/// **Forwards.** Setting it forward used to buy a whole fresh day, and the
/// trade-offs said so in as many words: it could not be caught without a
/// server, and Quiet has no server. That was true of a server and false of the
/// *answer* — every page the app loads comes back carrying Instagram's own
/// `Date` header, and a page is something the app was loading anyway. When one
/// of those arrives it is paired with the device's uptime, which counts real
/// elapsed time from the last restart and which no settings screen can touch.
/// From then on the app knows what time it is regardless of what the phone
/// says, and a date moved forward is simply ignored.
///
/// The anchor mends the other direction too, which nothing else could. A clock
/// pushed forward and then pulled back used to poison the high-water mark for
/// as long as the jump was wide — the app froze, correctly by its own rule and
/// uselessly for the person holding it. A vouched-for instant that sits behind
/// the mark is evidence the mark was made of a lie, and it is lowered to meet
/// it.
final class MonotonicClock: TimeSource {
    private let base: any TimeSource
    private let store: any HighWaterMarkStore
    private let uptime: () -> TimeInterval

    /// Only persist once the mark has moved by this much, so that reading the
    /// time does not mean writing to the keychain several times a second.
    private static let persistGranularity: TimeInterval = 60

    /// How far the device may disagree with a vouched-for instant before the
    /// disagreement is treated as a fact rather than as skew.
    ///
    /// Generous on purpose. A `Date` header is accurate to the second and a
    /// phone on automatic time is accurate to rather better than this, so ten
    /// minutes is far more room than either needs — and it is three orders of
    /// magnitude short of the thing being defended against, which is a day.
    static let tolerance: TimeInterval = 10 * 60

    private var mark: Date
    private var persistedMark: Date

    /// The most recent instant somebody other than this phone vouched for.
    private var anchor: TimeAnchor?

    init(
        base: any TimeSource = SystemTimeSource(),
        store: any HighWaterMarkStore,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.base = base
        self.store = store
        self.uptime = uptime
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

    /// Somebody else said what time it is.
    ///
    /// Taken from the `Date` header of a page Instagram served, which is the
    /// only reading in the app that the phone did not produce itself. A later
    /// anchor always replaces an earlier one; there is no averaging and no
    /// history, because the newest answer is the best one and keeping the rest
    /// would only be a record of where somebody has been.
    func vouch(_ instant: Date) {
        let heard = TimeAnchor(instant: instant, uptime: uptime())
        anchor = heard

        // A mark made while the clock was pushed forward is a mark made of a
        // lie. Nothing but an anchor can know that, and this is the only place
        // in the app where the mark is allowed to move down.
        let vouched = heard.now(at: uptime())
        guard mark > vouched.addingTimeInterval(Self.tolerance) else { return }
        mark = vouched
        persistedMark = vouched
        store.highWaterMark = vouched
    }

    /// What the app believes the time is.
    ///
    /// The device's own answer, unless something vouched for a different one
    /// and the device is *ahead* of it. Behind is not this rule's business —
    /// that is the high-water mark below, which has always handled it and
    /// handles it for the offline case too.
    private var believed: Date {
        let actual = base.now
        guard let anchor else { return actual }
        let vouched = anchor.now(at: uptime())
        return actual > vouched.addingTimeInterval(Self.tolerance) ? vouched : actual
    }

    var now: Date {
        let actual = believed
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
        believed < mark.addingTimeInterval(-Self.persistGranularity)
    }

    /// True when the device clock sits ahead of an instant that was vouched
    /// for. Surfaced for the same reason a rewind is: the app is about to
    /// behave in a way that will not match what the phone is showing, and
    /// saying so is better than being mysteriously stubborn.
    ///
    /// False whenever nothing has vouched for anything, which is the honest
    /// answer offline: not "the clock is fine", but "nobody has said".
    var isAdvanced: Bool {
        guard let anchor else { return false }
        return base.now > anchor.now(at: uptime()).addingTimeInterval(Self.tolerance)
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
