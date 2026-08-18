import Foundation

/// A day, as a person lives it.
///
/// Quiet's day begins at 4 a.m., not midnight. The hours after midnight belong
/// to the evening you are still awake in — the one place a midnight reset would
/// hand out a second daily allowance exactly when self-control is thinnest.
enum QuietDay {
    /// The hour a Quiet day begins, in local time.
    static let startHour = 4

    /// Four in the morning on the calendar day that `date` falls in.
    ///
    /// Built by setting the hour rather than by adding four hours to midnight.
    /// On the morning the clocks go forward, those are not the same instant:
    /// adding four hours lands on 05:00, because an hour of the night does not
    /// exist. Twice a year that would move the moment the day turns, and it
    /// would move it for the boundary without moving it for the day's identity
    /// — so the two would disagree about which day it was.
    static func boundary(onTheDayOf date: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: date)
        return calendar.date(
            bySettingHour: startHour,
            minute: 0,
            second: 0,
            of: midnight,
            matchingPolicy: .nextTime
        ) ?? midnight.addingTimeInterval(Double(startHour) * 3600)
    }
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

    /// The day that `date` falls in: the one whose 4 a.m. is the last to have
    /// passed.
    init(_ date: Date, calendar: Calendar = .current) {
        var day = calendar.startOfDay(for: date)
        if date < QuietDay.boundary(onTheDayOf: day, calendar: calendar) {
            // Before four in the morning, so this still belongs to yesterday.
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        let reference = calendar.startOfDay(for: DayKey.referenceDate)
        ordinal = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
    }

    /// The instant this day begins: 4 a.m. local time.
    func start(calendar: Calendar = .current) -> Date {
        let reference = calendar.startOfDay(for: DayKey.referenceDate)
        let midnight = calendar.date(byAdding: .day, value: ordinal, to: reference) ?? reference
        return QuietDay.boundary(onTheDayOf: midnight, calendar: calendar)
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
