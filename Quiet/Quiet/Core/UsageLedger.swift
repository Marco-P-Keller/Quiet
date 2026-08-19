import Foundation

/// How much of today has been spent.
///
/// One day at a time: Quiet keeps today's total and nothing else. There is no
/// history to browse, no weekly graph, no streak. A record of how much you
/// scrolled is one more thing to check.
struct UsageLedger: Codable, Equatable, Sendable {
    private(set) var day: DayKey
    private(set) var seconds: TimeInterval

    /// When this day is allowed to end, fixed at the moment it began.
    ///
    /// The day turns at 4 a.m. wherever you are, which means the time zone is
    /// part of the rule — and a time zone is two taps away in Settings. Without
    /// this, moving the phone to Kiritimati advances the local date and hands
    /// out a fresh allowance, and moving it to Honolulu does the same on the way
    /// back, because a day that is merely *different* was treated as a day that
    /// had *passed*.
    ///
    /// Deciding the ending when the day starts settles it: the day you are in
    /// keeps the length it was born with, and the next one starts at 4 a.m.
    /// wherever you have landed. Optional because ledgers written by earlier
    /// versions do not carry it.
    private(set) var endsAt: Date?

    init(day: DayKey, seconds: TimeInterval = 0, endsAt: Date? = nil) {
        self.day = day
        self.seconds = max(0, seconds)
        self.endsAt = endsAt
    }

    /// Move to `today`, discarding a previous day's total. Idempotent.
    ///
    /// `endingAt` is when the new day may itself be replaced. A ledger with no
    /// ending is one that was written before this rule existed; it gets one
    /// here rather than being distrusted.
    mutating func roll(to today: DayKey, endingAt: Date? = nil) {
        guard today != day else { return }
        day = today
        seconds = 0
        endsAt = endingAt
    }

    /// Whether `now` is past the ending this day was given.
    ///
    /// A ledger from before this rule has no ending, and gets the benefit of the
    /// doubt: the old behaviour, where any different day was a new day.
    func hasEnded(by now: Date) -> Bool {
        guard let endsAt else { return true }
        return now >= endsAt
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
