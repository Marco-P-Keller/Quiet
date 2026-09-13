import Foundation

/// One notification, already written, waiting for its moment.
///
/// A local notification carries its text from the instant it is scheduled, not
/// from the instant it arrives — nothing runs on Quiet's behalf while the app
/// is closed, and nothing ever will, because the whole app is built around not
/// having a server. So every sentence a recap will ever say has to be true at
/// the moment it is put on the phone, and has to stay true if nobody opens the
/// app again. See `Recap.chimes`, which is where that is arranged.
struct Chime: Equatable, Sendable {
    /// Named after its instant and its kind, so the same recap scheduled twice
    /// is one notification rather than two.
    var id: String
    var at: Date
    var title: String
    var body: String
}

/// What Quiet says about the days behind you, and when.
///
/// The appointment says the window is open. This says what the window came to.
/// They are separate switches because they are opposite errands: one is an
/// invitation, and arrives before; the other is an account, and arrives after.
/// Somebody may well want the second and not the first.
struct Recap: Codable, Equatable, Sendable {
    /// On, and this is the one preference in Quiet that is.
    ///
    /// Everything else here is off until somebody asks, and that rule is worth
    /// more than any single feature — an app that opts you into things is an
    /// app you have to audit. The argument for making this the exception is
    /// that it is the only setting whose *whole* value is arriving unprompted:
    /// a note about the days behind you, which you have to remember to go and
    /// switch on before it can ever tell you anything, is a note that reaches
    /// the people who least need it.
    ///
    /// It costs a permission prompt, and iOS will not let it cost anything
    /// less — a notification nobody has authorised is not a quiet notification,
    /// it is no notification, and a switch standing at "on" over that would be
    /// this app lying about the one thing it is careful about. So the prompt is
    /// asked once, at the end of setup rather than at launch, and a "no" turns
    /// this straight back off. See `QuietSession.askAboutTheMorningNote`.
    var isOn: Bool

    /// Minutes after midnight, local time. One number for the same reason the
    /// appointment keeps one.
    var minutesAfterMidnight: Int

    /// Mid-morning: after the day it is reporting on has properly ended, and
    /// before the day it is reporting to has got going.
    static let standard = Recap(isOn: true, minutesAfterMidnight: 9 * 60)

    var hour: Int { minutesAfterMidnight / 60 }
    var minute: Int { minutesAfterMidnight % 60 }

    /// How many days of recaps are put on the phone at once, for the same
    /// reason `Appointment.horizon` exists: iOS holds them, so they arrive
    /// whether or not the app runs again.
    static let horizon = 7

    /// What a recap is about.
    enum Span: Equatable, Sendable {
        /// The day that has just ended.
        case day
        /// The seven days ending with it, when it was the last day of a week.
        case week
        /// The calendar month it closed, when it was the last day of one.
        case month
    }

    /// The recaps to put on the phone, soonest first.
    ///
    /// Pure, so the rule can be read and tested without a phone.
    ///
    /// Two things decide whether a given morning gets one at all. The first is
    /// that its window has to contain a day Quiet was actually open for —
    /// otherwise an app somebody stopped using would keep telling them, every
    /// morning for a week, how much it was saving them. The second is that the
    /// figures come from `record`, which is what is known *now*; a recap for
    /// the morning after tomorrow is written against a tomorrow that has not
    /// happened. That is not a guess going wrong, because every launch and
    /// every trip to the background recomputes the whole set — the only recap
    /// that survives unrevised is one for a day the app was never opened on,
    /// and for that day the figures were right.
    func chimes(
        after now: Date,
        record: History,
        baselineMinutes: Int,
        calendar: Calendar = .current,
        horizon: Int = Recap.horizon
    ) -> [Chime] {
        guard isOn, baselineMinutes > 0 else { return [] }

        var found: [Chime] = []
        // One more day than the horizon: this morning's may already be behind
        // us, in which case the week starts tomorrow and still has to be a week.
        for offset in 0...horizon {
            guard let midnight = calendar.date(
                byAdding: .day,
                value: offset,
                to: calendar.startOfDay(for: now)
            ) else { continue }
            guard let ring = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: midnight,
                matchingPolicy: .nextTime
            ) else { continue }
            guard ring > now else { continue }

            if let chime = Recap.chime(
                at: ring,
                record: record,
                baselineMinutes: baselineMinutes,
                calendar: calendar
            ) {
                found.append(chime)
                if found.count == horizon { break }
            }
        }
        return found
    }

    /// The recap for one instant, or nothing if there is nothing to say.
    static func chime(
        at ring: Date,
        record: History,
        baselineMinutes: Int,
        calendar: Calendar = .current
    ) -> Chime? {
        // The Quiet day that has ended by the time this rings. Not the calendar
        // day: Quiet's turns at four in the morning, and a recap at nine is
        // reporting on the day that closed five hours earlier.
        let closed = DayKey(ring, calendar: calendar).adding(days: -1)
        let span = span(closing: closed, calendar: calendar)
        let window = window(for: span, closing: closed, calendar: calendar)

        // Nothing is said about days Quiet was not there for. See `History`.
        guard !record.days(in: window).isEmpty else { return nil }

        let spent = record.spent(in: window)
        let saved = record.saved(against: baselineMinutes, in: window)

        return Chime(
            id: "quiet.recap.\(Int(ring.timeIntervalSince1970))",
            at: ring,
            title: title(for: span),
            body: body(for: span, spent: spent, saved: saved)
        )
    }

    /// Which of the three a day closes.
    ///
    /// Read off the day *after* it rather than off the day itself, which is the
    /// only way that survives a month ending on a Sunday and a reader who put
    /// their recap at two in the morning. A day is the last of its month when
    /// the next one is in a different month, and the last of its week when the
    /// next one is the first weekday — whichever weekday that is where the
    /// phone is, because half the world does not start on Monday.
    static func span(closing day: DayKey, calendar: Calendar = .current) -> Span {
        let opens = day.next.start(calendar: calendar)
        if calendar.component(.month, from: day.start(calendar: calendar))
            != calendar.component(.month, from: opens) {
            return .month
        }
        if calendar.component(.weekday, from: opens) == calendar.firstWeekday {
            return .week
        }
        return .day
    }

    /// The days a recap covers.
    static func window(
        for span: Span,
        closing day: DayKey,
        calendar: Calendar = .current
    ) -> ClosedRange<DayKey> {
        switch span {
        case .day:
            return day...day
        case .week:
            return day.adding(days: -6)...day
        case .month:
            let noon = day.start(calendar: calendar).addingTimeInterval(8 * 3600)
            var parts = calendar.dateComponents([.year, .month], from: noon)
            parts.day = 1
            parts.hour = 12
            guard let first = calendar.date(from: parts) else { return day...day }
            return DayKey(first, calendar: calendar)...day
        }
    }

    private static func title(for span: Span) -> String {
        switch span {
        case .day: return String(localized: "Yesterday")
        case .week: return String(localized: "Last week")
        case .month: return String(localized: "Last month")
        }
    }

    /// What it says.
    ///
    /// Two sentences at most, and the second one only when there is a saving to
    /// report. "Nothing less than before" is not a thing worth waking a phone
    /// up for, and a zero dressed up as an achievement is the register this app
    /// spends its whole time avoiding.
    ///
    /// The claim is deliberately narrow: fewer minutes *here*, against a number
    /// you gave. Not "you got an hour back" — Quiet has no idea where the hour
    /// went, and cannot see the real Instagram app at all.
    private static func body(for span: Span, spent: TimeInterval, saved: TimeInterval) -> String {
        let time = Phrase.span(spent)
        guard saved >= 60 else {
            switch span {
            case .day: return String(localized: "\(time) on Instagram.")
            case .week: return String(localized: "\(time) on Instagram over the week.")
            case .month: return String(localized: "\(time) on Instagram over the month.")
            }
        }
        let less = Phrase.span(saved)
        switch span {
        case .day:
            return String(localized: "\(time) on Instagram — \(less) less than the day you started from.")
        case .week:
            return String(localized: "\(time) on Instagram over the week — \(less) less than those days used to be.")
        case .month:
            return String(localized: "\(time) on Instagram over the month — \(less) less than those days used to be.")
        }
    }
}
