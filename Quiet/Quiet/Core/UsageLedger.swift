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

    /// How many of today's minutes came from the Instagram app, by way of
    /// Screen Time, and are already counted in `seconds`.
    ///
    /// Kept so that the same report can be read any number of times and only
    /// what is new is added. Optional because ledgers written before the limit
    /// could reach the Instagram app do not carry it, and for them it is zero.
    private(set) var fromTheApp: Int?

    init(day: DayKey, seconds: TimeInterval = 0, endsAt: Date? = nil, fromTheApp: Int? = nil) {
        self.day = day
        self.seconds = max(0, seconds)
        self.endsAt = endsAt
        self.fromTheApp = fromTheApp
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
        fromTheApp = nil
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

    /// Take the Instagram app's total for today, as Screen Time reports it, and
    /// add whatever part of it is new. Returns whether anything was.
    ///
    /// Not subject to `plausibleTick`. That rule is about a clock reading that
    /// jumped; this is a count somebody else kept, and an afternoon spent in the
    /// Instagram app while Quiet sat closed arrives here as one large number
    /// that is perfectly true.
    @discardableResult
    mutating func credit(appMinutes total: Int) -> Bool {
        let before = fromTheApp ?? 0
        guard total > before else { return false }
        seconds += TimeInterval(total - before) * 60
        fromTheApp = total
        return true
    }

    /// Today's total without the Instagram app's share: Quiet, and the
    /// reader's other devices if the limit is carried between them.
    var secondsInQuiet: TimeInterval {
        max(0, seconds - TimeInterval(fromTheApp ?? 0) * 60)
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
    ///
    /// The number itself lives in `Elapsed`, because the same rule is applied
    /// by the counter that decides whether the app may ask what you think of
    /// it, and two copies of a number are two numbers.
    static let plausibleTick: TimeInterval = Elapsed.plausible
}
