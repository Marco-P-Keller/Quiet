import Foundation

/// The other way into Instagram: the Instagram app itself.
///
/// Quiet's limit used to stop at the edge of Quiet. Anybody who kept the
/// Instagram app on their phone had a second door, with no limit on it at all,
/// and the curtain coming down in one app was an invitation to open the other.
/// When somebody asks for it, Screen Time now counts the Instagram app against
/// the same daily minutes and closes it when they are spent.
///
/// The session talks to that through this, and only this, so that every rule
/// about the day can still be tested without Screen Time anywhere near it —
/// Screen Time does not run in a test, and its tokens cannot be made by one.
@MainActor
protocol InstagramAppDoor: AnyObject {
    /// Minutes the Instagram app has had on `day`, as far as Screen Time has
    /// said. Zero when the limit does not reach it.
    func minutes(on day: DayKey) -> Int

    /// The limit, and how much of today Quiet itself has spent.
    func tell(_ terms: Terms)

    /// Today is spent: close the Instagram app too, until `until`.
    func close(until: Date, today: DayKey)

    /// A day may have begun. Open whatever was closed for a day that has ended.
    func morning(now: Date, today: DayKey)

    /// Everything is being forgotten; take back everything asked of Screen Time.
    func forget()
}

/// The door when there is no Screen Time to speak of: in a test, on a phone
/// older than iOS 17.4, and for anybody who has not switched it on — in which
/// case the real one behaves exactly like this anyway.
final class NoInstagramAppDoor: InstagramAppDoor {
    func minutes(on day: DayKey) -> Int { 0 }
    func tell(_ terms: Terms) {}
    func close(until: Date, today: DayKey) {}
    func morning(now: Date, today: DayKey) {}
    func forget() {}
}
