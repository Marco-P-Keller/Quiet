import Foundation

/// How much of today has been spent.
///
/// One day at a time: Quiet keeps today's total and nothing else. There is no
/// history to browse, no weekly graph, no streak. A record of how much you
/// scrolled is one more thing to check.
struct UsageLedger: Codable, Equatable, Sendable {
    private(set) var day: DayKey
    private(set) var seconds: TimeInterval

    init(day: DayKey, seconds: TimeInterval = 0) {
        self.day = day
        self.seconds = max(0, seconds)
    }

    /// Move to `today`, discarding a previous day's total. Idempotent.
    mutating func roll(to today: DayKey) {
        guard today != day else { return }
        day = today
        seconds = 0
    }

    /// Add foreground time. Amounts that are zero, negative, or absurd — the
    /// shape of a clock jump rather than a person looking at a screen — are
    /// ignored.
    mutating func add(_ interval: TimeInterval) {
        guard interval > 0, interval < UsageLedger.plausibleTick else { return }
        seconds += interval
    }

    func remaining(limitMinutes: Int) -> TimeInterval {
        max(0, TimeInterval(limitMinutes) * 60 - seconds)
    }

    func isSpent(limitMinutes: Int) -> Bool {
        remaining(limitMinutes: limitMinutes) <= 0
    }

    /// The longest single stretch Quiet will credit in one go. Foreground time
    /// is sampled every few seconds, so anything near an hour is a bad reading,
    /// not a fact.
    static let plausibleTick: TimeInterval = 3600
}
