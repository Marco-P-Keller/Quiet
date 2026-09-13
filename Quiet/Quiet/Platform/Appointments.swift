import Foundation
import UserNotifications

/// The phone's own notification centre, behind the smallest surface that will
/// do.
///
/// Everything worth arguing about — which days, and none on a day already
/// spent — is decided in `Appointment` and `Recap`, and tested there. This hands
/// the answers over and nothing else.
@MainActor
final class SystemRinger: Ringer {
    private let centre: UNUserNotificationCenter

    /// The two families of notification this app puts on a phone.
    ///
    /// Prefixes rather than a stored list, because the list has to survive the
    /// app being killed: identifiers written by one launch are still pending in
    /// the next, and a set held in memory would not know about them. A prefix is
    /// a question the notification centre can answer at any time.
    private static let appointmentFamily = "quiet.appointment."
    private static let recapFamily = "quiet.recap."

    init(centre: UNUserNotificationCenter = .current()) {
        self.centre = centre
    }

    /// Asked at the moment a reminder is switched on, and never before.
    ///
    /// A permission prompt on the first launch is a toll gate in front of an
    /// app somebody has not decided to use yet, and Quiet has never had one.
    /// This one arrives attached to a switch that was just pressed, which is
    /// the only time a person can answer it meaningfully.
    ///
    /// Alerts and a sound, and deliberately no badge. A number on the icon is
    /// one more thing to check, and this whole feature exists to have fewer of
    /// those.
    func ask() async -> Bool {
        (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func ring(at times: [Date]) {
        replace(family: Self.appointmentFamily, with: times.map { time in
            Chime(
                id: Self.appointmentFamily + String(Int(time.timeIntervalSince1970)),
                at: time,
                title: String(localized: "Quiet"),
                body: String(localized: "Your Instagram window is open.")
            )
        })
    }

    func chime(_ chimes: [Chime]) {
        replace(family: Self.recapFamily, with: chimes)
    }

    func silence() {
        centre.removeAllPendingNotificationRequests()
    }

    /// Put exactly these on the phone, and take down whatever else of the same
    /// family was there.
    ///
    /// Family by family rather than everything at once, which is what the whole
    /// prefix business is for. The set of pending reminders of one kind is
    /// recomputed from scratch whenever anything about it changes; doing that by
    /// clearing the lot would mean every recomputation of the recaps quietly
    /// unscheduled the appointment, and the failure would be a notification that
    /// simply never arrived — the hardest kind of bug to be told about.
    ///
    /// The pending list can only be asked for with a callback, and the callback
    /// does not come back on the main actor. Nothing of `self` crosses over:
    /// the centre and the chimes go in, and requests are built on the far side.
    private func replace(family: String, with chimes: [Chime]) {
        let centre = self.centre
        centre.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(family) }
            if !stale.isEmpty {
                centre.removePendingNotificationRequests(withIdentifiers: stale)
            }
            for chime in chimes {
                let content = UNMutableNotificationContent()
                content.title = chime.title
                content.body = chime.body
                content.sound = .default

                var parts = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: chime.at
                )
                parts.second = 0
                // A dated request rather than a repeating one, because neither
                // rule is "every day at six": the appointment is "every day at
                // six that you have not already been", and a recap carries a
                // sentence that is only true of the morning it was written for.
                // A repeating trigger cannot be told about either half.
                centre.add(UNNotificationRequest(
                    identifier: chime.id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                ))
            }
        }
    }
}
