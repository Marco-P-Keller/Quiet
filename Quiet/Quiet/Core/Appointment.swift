import Foundation

/// A time of day Quiet may ring at, and the one rule about when it does not.
///
/// The problem it answers is the one thing a web client cannot: without
/// notifications, "has anything happened?" is a question that can only be
/// answered by opening the app — so it gets opened, briefly, several times a
/// day, which is exactly the habit the limit was bought to break.
///
/// The obvious fix is not available and never will be. A notification saying a
/// message arrived can only come from something that knows a message arrived,
/// which is Instagram, and Instagram pushes to its own app. Anything else means
/// a machine somewhere else logged in as you, and that is the one thing this app
/// promises never to be.
///
/// So this answers a different question. It does not tell you whether anything
/// happened; it tells you that the window is open, once, at a time you chose.
/// The point is not the ping. The point is that the rest of the day needs no
/// checking, because the checking has an hour.
struct Appointment: Codable, Equatable, Sendable {
    /// Off until somebody asks for it. Nothing in Quiet is opt-out.
    var isOn: Bool

    /// Minutes after midnight, local time.
    ///
    /// One number rather than an hour and a minute, because two numbers that
    /// must agree are a way to be wrong. Converted at the edges, where a
    /// calendar is at hand.
    var minutesAfterMidnight: Int

    /// Early evening: after most people's day and before most people's night.
    /// Only ever a starting point for the picker — the whole feature is that
    /// the hour is yours.
    static let standard = Appointment(isOn: false, minutesAfterMidnight: 18 * 60)

    var hour: Int { minutesAfterMidnight / 60 }
    var minute: Int { minutesAfterMidnight % 60 }

    /// How many days are put on the phone at once.
    ///
    /// iOS holds pending notifications itself, so they arrive whether or not
    /// the app ever runs again — which is the whole reason this works without a
    /// server, and the reason the number is not larger. A week of reminders is
    /// what an app you have stopped opening is allowed to say before it stops
    /// talking. Every launch tops the week back up.
    static let horizon = 7

    /// The instants this appointment should ring at, soonest first.
    ///
    /// Pure, so the rule below can be read and tested without a phone.
    ///
    /// - Parameter openedToday: whether Instagram has already been on screen
    ///   today. When it has, today's ring is dropped. A reminder that the
    ///   window is open is worth having; the same reminder after you have been
    ///   through the window is an invitation to go again, which is the opposite
    ///   of what this is for.
    func rings(
        after now: Date,
        openedToday: Bool,
        calendar: Calendar = .current,
        horizon: Int = Appointment.horizon
    ) -> [Date] {
        guard isOn else { return [] }

        let todayHere = DayKey(now, calendar: calendar)
        var found: [Date] = []
        // One more day than the horizon: today's ring may already be behind us,
        // in which case the week starts tomorrow and still has to be a week.
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

            // An hour that has passed, or one the clocks skipped over this
            // morning and `nextTime` landed on the far side of.
            guard ring > now else { continue }
            // The app's own day, not the calendar's: an appointment at two in
            // the morning belongs to the evening you are still awake in, and
            // that is the day the ledger is counting.
            if openedToday && DayKey(ring, calendar: calendar) == todayHere { continue }

            found.append(ring)
            if found.count == horizon { break }
        }
        return found
    }
}

/// Something that can put a handful of reminders on the phone and take them off
/// again.
///
/// A protocol for one reason: what the session decides — how many rings, on
/// which days, and none at all on a day already spent — is worth a test, and
/// `UNUserNotificationCenter` cannot be one.
/// On the main actor, so that handing one to the session never means handing a
/// mutable object across an isolation boundary. The notification centre is
/// perfectly happy to be asked from there.
@MainActor
protocol Ringer: AnyObject {
    /// Ask the phone for permission. `false` if it says no, and it is asked
    /// only at the moment somebody switches the reminder on.
    func ask() async -> Bool

    /// Replace whatever was pending with exactly these instants.
    func ring(at times: [Date])

    /// Take everything off.
    func silence()
}
