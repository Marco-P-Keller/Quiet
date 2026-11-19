import DeviceActivity
import Foundation

/// Woken by Screen Time, never by Quiet, and kept for as long as one call takes.
///
/// It does three things and keeps nothing between them: write down how many
/// minutes the Instagram app has had today, close it when that and Quiet's own
/// minutes together reach the limit, and open it again when the day turns at
/// four. Every decision is `ScreenTime`'s and `Verdict`'s, shared with the app
/// so that the two halves cannot come to different answers about the same day.
///
/// The extension runs under a few megabytes of memory and no user interface,
/// which is why there is nothing here but Foundation and the shelf.
final class Monitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard #available(iOS 17.4, *) else { return }
        let now = Date()
        ScreenTime.morning(now: now, today: DayKey(now))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard #available(iOS 17.4, *) else { return }
        let now = Date()
        ScreenTime.morning(now: now, today: DayKey(now))
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard #available(iOS 17.4, *),
              let minutes = Milestones.minutes(event.rawValue) else { return }
        let now = Date()
        ScreenTime.reached(minutes, now: now, today: DayKey(now))
    }
}
