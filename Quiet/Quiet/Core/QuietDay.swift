import Foundation

/// A day, as a person lives it.
///
/// Quiet's day begins at 4 a.m., not midnight. The hours after midnight belong
/// to the evening you are still awake in — the one place a midnight reset would
/// hand out a second daily allowance exactly when self-control is thinnest.
enum QuietDay {
    /// The hour a Quiet day begins, in local time.
    static let startHour = 4
}

/// The identity of a single Quiet day.
///
/// Stored as a count of days so that "seven days later" is arithmetic rather
/// than calendar guesswork, while conversion to and from `Date` stays in the
/// user's own calendar and time zone.
struct DayKey: Codable, Hashable, Comparable, CustomStringConvertible, Sendable {
    /// Days elapsed since the reference day, counted on the 4 a.m. boundary.
    let ordinal: Int

    init(ordinal: Int) {
        self.ordinal = ordinal
    }

    /// The day that `date` falls in.
    init(_ date: Date, calendar: Calendar = .current) {
        let shifted = date.addingTimeInterval(-Double(QuietDay.startHour) * 3600)
        let start = calendar.startOfDay(for: shifted)
        let reference = calendar.startOfDay(for: DayKey.referenceDate)
        ordinal = calendar.dateComponents([.day], from: reference, to: start).day ?? 0
    }

    /// The instant this day begins: 4 a.m. local time.
    func start(calendar: Calendar = .current) -> Date {
        let reference = calendar.startOfDay(for: DayKey.referenceDate)
        let midnight = calendar.date(byAdding: .day, value: ordinal, to: reference) ?? reference
        return calendar.date(byAdding: .hour, value: QuietDay.startHour, to: midnight) ?? midnight
    }

    /// The instant this day ends, which is the moment the next one begins.
    func end(calendar: Calendar = .current) -> Date {
        next.start(calendar: calendar)
    }

    var next: DayKey { DayKey(ordinal: ordinal + 1) }

    func adding(days: Int) -> DayKey { DayKey(ordinal: ordinal + days) }

    /// Whole days from this day to `other`. Negative when `other` is earlier.
    func days(to other: DayKey) -> Int { other.ordinal - ordinal }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.ordinal < rhs.ordinal }

    var description: String { "day \(ordinal)" }

    /// 1 January 2001, local time. Any fixed date works; this one keeps the
    /// ordinals small enough to read in a debugger.
    private static let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
}
