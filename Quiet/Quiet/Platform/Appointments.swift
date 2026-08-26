import Foundation
import UserNotifications

/// The phone's own notification centre, behind the smallest surface that will
/// do.
///
/// Everything worth arguing about — which days, and none on a day already
/// spent — is decided in `Appointment` and tested there. This hands the
/// answers over and nothing else.
@MainActor
final class SystemRinger: Ringer {
    private let centre: UNUserNotificationCenter

    init(centre: UNUserNotificationCenter = .current()) {
        self.centre = centre
    }

    /// Asked at the moment the reminder is switched on, and never before.
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
        // Cleared first rather than added to. The set of pending reminders is
        // recomputed from scratch on every launch, so anything still on the
        // phone was decided by an older answer to the same question.
        silence()
        for time in times {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Quiet")
            content.body = String(localized: "Your Instagram window is open.")
            content.sound = .default

            var parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: time
            )
            parts.second = 0
            // A dated request rather than a repeating one, because the rule is
            // not "every day at six": it is "every day at six that you have not
            // already been". A repeating trigger cannot be told about the
            // second half.
            let request = UNNotificationRequest(
                identifier: Self.name(for: time),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            )
            centre.add(request)
        }
    }

    func silence() {
        centre.removeAllPendingNotificationRequests()
    }

    /// Named after the instant it is for, so the same day scheduled twice is
    /// one reminder rather than two.
    private static func name(for time: Date) -> String {
        "quiet.appointment.\(Int(time.timeIntervalSince1970))"
    }
}
