import Foundation

/// One day, and how much of it went to Instagram.
struct DayRecord: Codable, Equatable, Sendable {
    let day: DayKey
    var seconds: TimeInterval

    init(day: DayKey, seconds: TimeInterval) {
        self.day = day
        self.seconds = max(0, seconds)
    }
}

/// The days behind you.
///
/// This is the one thing in Quiet that used to be deliberately absent. The
/// ledger's own note still says why: *a record of how much you scrolled is one
/// more thing to check*, and that argument has not stopped being true. What
/// changed is that the app now asks, on the first screen, how much Instagram a
/// day was before any of this — and a number somebody gave you is a promise you
/// have to be able to answer. Without days behind you there is nothing to
/// answer it with.
///
/// Two rules keep it from becoming the thing the ledger was warning about.
///
/// * **Only days Quiet was actually there for.** A day with no entry counts for
///   nothing: not time spent, and not time saved. The alternative — treating an
///   unopened day as a whole baseline rescued — would mean somebody who
///   installed Quiet and never opened it again was told every morning how much
///   it was doing for them, while they scrolled the real app. That is the exact
///   lie this feature is one bad decision away from.
/// * **Completed days only.** Today is still running and its number still moves;
///   it lives in the ledger, where the rest of the app already looks for it.
///   Anything that wants both asks the session for `record`, which folds the
///   running day in at the moment of asking.
struct History: Codable, Equatable, Sendable {
    /// Oldest first, one entry per day, no gaps filled in.
    private(set) var days: [DayRecord]

    /// How many days are kept.
    ///
    /// A year and a bit. Long enough that "since you started" means something
    /// after a year of use, short enough that the whole thing stays a few
    /// kilobytes — it is written to the keychain, which is not a database and
    /// should not be asked to be one.
    static let horizon = 400

    init(days: [DayRecord] = []) {
        self.days = Array(days.sorted { $0.day < $1.day }.suffix(Self.horizon))
    }

    /// Write down what a day came to. Replaces an existing entry for that day.
    ///
    /// Idempotent on purpose: the day is recorded when it rolls, and a roll can
    /// be noticed twice — once by the tick and once by the app coming forward
    /// — without the second one doubling anything.
    mutating func record(_ day: DayKey, seconds: TimeInterval) {
        let entry = DayRecord(day: day, seconds: seconds)
        if let index = days.firstIndex(where: { $0.day == day }) {
            days[index] = entry
        } else if let index = days.firstIndex(where: { $0.day > day }) {
            days.insert(entry, at: index)
        } else {
            days.append(entry)
        }
        if days.count > Self.horizon {
            days.removeFirst(days.count - Self.horizon)
        }
    }

    /// What a day came to, or `nil` if Quiet was not opened on it.
    func seconds(on day: DayKey) -> TimeInterval? {
        days.first { $0.day == day }?.seconds
    }

    /// The entries inside a window, which may be none.
    func days(in window: ClosedRange<DayKey>) -> [DayRecord] {
        days.filter { window.contains($0.day) }
    }

    /// The first day there is anything written down about.
    var began: DayKey? { days.first?.day }

    /// Time on Instagram across a window.
    func spent(in window: ClosedRange<DayKey>) -> TimeInterval {
        days(in: window).reduce(0) { $0 + $1.seconds }
    }

    /// Time *not* spent, measured against the day somebody said they were
    /// having before Quiet.
    ///
    /// Per day and floored at nothing, rather than one subtraction across the
    /// whole window. The difference shows up on a day somebody went over their
    /// old average: floored per day, that day contributes nothing; subtracted
    /// in bulk, it would quietly eat the saving from the days either side of
    /// it. The first is the reading a person would give of their own week.
    func saved(against baselineMinutes: Int, in window: ClosedRange<DayKey>) -> TimeInterval {
        let baseline = TimeInterval(max(0, baselineMinutes)) * 60
        return days(in: window).reduce(0) { $0 + max(0, baseline - $1.seconds) }
    }

    /// The same, across everything written down.
    func saved(against baselineMinutes: Int) -> TimeInterval {
        guard let first = days.first?.day, let last = days.last?.day else { return 0 }
        return saved(against: baselineMinutes, in: first...last)
    }

    /// A run of days ending on `day`, with the ones Quiet never saw included as
    /// blanks.
    ///
    /// The blanks are what makes it a chart rather than a list. A week with two
    /// missing days is seven columns, two of them empty — not five columns
    /// pretending to be a week.
    func run(endingOn day: DayKey, length: Int) -> [(day: DayKey, seconds: TimeInterval?)] {
        guard length > 0 else { return [] }
        return (0..<length).reversed().map { offset in
            let key = day.adding(days: -offset)
            return (day: key, seconds: seconds(on: key))
        }
    }
}
