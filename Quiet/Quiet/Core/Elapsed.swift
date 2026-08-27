import Foundation

/// How much elapsed time Quiet is prepared to believe in one reading.
///
/// Two places count time by subtracting one uptime reading from another: the
/// ledger, which spends the day, and `Applause`, which decides whether the app
/// has earned the right to ask a question. Both had their own copy of the same
/// number and the same paragraph explaining it, which is one copy too many —
/// the day they disagree, one of them is wrong and nothing says which.
enum Elapsed {
    /// The longest single stretch either counter will credit.
    ///
    /// Foreground time is sampled every second or so, and the app is asked how
    /// long it has been on screen only while it *is* on screen. Anything
    /// approaching an hour is therefore not a person looking at a phone; it is
    /// the shape of a clock jumping, a device waking from a long standby, or a
    /// reading taken across a suspension. Those are dropped rather than
    /// trusted: a wrong reading of this size would spend somebody's whole day
    /// in one tick.
    static let plausible: TimeInterval = 60 * 60
}
