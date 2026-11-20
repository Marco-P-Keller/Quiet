import Foundation
import Observation

/// When, if ever, to ask what somebody thinks of the app.
///
/// Asking is a small rudeness, so it gets exactly one shot and it has to earn
/// it. Three conditions, and all of them matter:
///
/// - Five minutes of the app actually in front of somebody. Not five minutes
///   since it was installed — an app can sit unopened for a week — and not one
///   long sitting either, because Quiet is built to be used in short ones and a
///   rule that only fires in a long sitting would fire for the people using it
///   worst.
/// - **Across three separate days.** The minutes alone were the whole rule
///   once, and at a five-minute minimum limit that is somebody's *first
///   sitting* — the app had been opened, and nothing it promises had happened
///   yet. What Quiet is for cannot be judged in one sitting: the promise is
///   that the limit holds, and holding is a thing that takes days to notice.
///   Three days is somebody who was cut off and came back anyway, which is the
///   only endorsement this app can actually earn.
/// - As often as Apple allows, and no oftener. iOS shows its own sheet at
///   most three times in any 365 days whatever an app asks for, so Quiet asks
///   at most once every `gap` days — four months, three a year — and only
///   after the minutes and the days have been earned again since the last
///   time. Asking more often than that would not show the sheet more often;
///   it would only spend the question on a moment iOS then swallows.
///
/// The shot is not spent more often for having waited — it is spent on
/// somebody in a position to answer.
///
/// Note what is deliberately *not* a condition: reaching the curtain. The end
/// of the day is the one moment in Quiet meant to be felt, and asking to be
/// rated on the far side of it would be the app asking to be praised for what
/// it has just taken away. `RootView` refuses to put the question anywhere but
/// the browsing screen for that reason, and this rule does not undo it — a day
/// counts because the app was opened on it, not because it ended.
///
/// The counting is deliberately plain: how long the app has been on screen. It
/// does not care which screen, and that is right — five minutes spent reading
/// the curtain is still five minutes of using Quiet, and rather more
/// characteristic of it than five minutes spent in the feed.
///
/// Kept in `UserDefaults`, beside the other things that are about the app
/// rather than about the promise. Reinstalling forgets it, which means somebody
/// who deleted the app and came back gets asked once more; that is the right
/// way round.
/// Where the two numbers are kept. At file scope so that a rehearsal can clear
/// them without stepping onto the main actor to do it.
private enum Key {
    static let spent = "quiet.applause.seconds"
    /// Written by versions that asked once, ever. Read once, to carry those
    /// readers across; never written again.
    static let asked = "quiet.applause.asked"
    static let askedIn = "quiet.applause.askedin"
    static let askedOn = "quiet.applause.askedon"
    static let days = "quiet.applause.days"
    static let lastDay = "quiet.applause.lastday"
}

@MainActor
@Observable
final class Applause {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let uptime: () -> TimeInterval

    /// What it takes.
    static let earned: TimeInterval = 3 * 60

    /// And on how many separate days. Three rather than two because two is
    /// "came back once", which a person does out of curiosity; three is a
    /// habit forming, and a habit forming is the thing being asked about.
    static let acrossDays = 2

    /// Time the app has been on screen, across every launch so far.
    private(set) var spent: TimeInterval

    /// How many separate days the app has been opened on.
    private(set) var days: Int

    /// The last day counted, so that opening the app nine times before lunch
    /// is one day and not nine. Stored as `DayKey`'s ordinal — the day Quiet
    /// means, which turns at four in the morning, rather than the calendar's.
    private(set) var lastDay: Int?

    /// Days between one question and the next: 365 / 3, rounded up, which is
    /// the most often iOS will ever show its sheet.
    static let gap = 122

    /// The day the question was last put, as `DayKey`'s ordinal.
    private(set) var askedOn: Int?

    /// Whether the question has been put recently enough that iOS would not
    /// show it again yet.
    var asked: Bool {
        guard let askedOn else { return false }
        return (lastDay ?? askedOn) - askedOn < Self.gap
    }

    /// Set while the app is in front of somebody. Measured against
    /// `systemUptime`, like everything else in Quiet that counts elapsed time,
    /// because it is the one clock no settings screen can move.
    @ObservationIgnored private var since: TimeInterval?

    init(
        defaults: UserDefaults = .standard,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.defaults = defaults
        self.uptime = uptime
        self.spent = defaults.double(forKey: Key.spent)
        self.askedOn = defaults.object(forKey: Key.askedOn) as? Int
        self.days = defaults.integer(forKey: Key.days)
        // `object(forKey:)` rather than `integer(forKey:)`: a missing key reads
        // as zero, and zero is a real ordinal. Nobody will open this app on the
        // day it stands for, but a rule that is only right because the date is
        // implausible is a rule that is wrong.
        self.lastDay = defaults.object(forKey: Key.lastDay) as? Int

        // Somebody asked by an earlier version, which wrote down only that it
        // had asked (once, ever) or which version it asked in. Long enough ago
        // for iOS to show the sheet again, but they start one day short of the
        // rule rather than being asked the second the new version opens.
        if askedOn == nil,
           defaults.bool(forKey: Key.asked) || defaults.string(forKey: Key.askedIn) != nil {
            spent = 0
            days = Self.acrossDays - 1
            defaults.set(spent, forKey: Key.spent)
            defaults.set(days, forKey: Key.days)
            defaults.removeObject(forKey: Key.asked)
            defaults.removeObject(forKey: Key.askedIn)
        defaults.removeObject(forKey: Key.askedOn)
        }
    }

    /// How much longer, from what has been banked so far.
    var remaining: TimeInterval { max(0, Self.earned - spent) }

    /// Whether the moment has come. Read after `bank()`.
    var isDue: Bool { !asked && spent >= Self.earned && days >= Self.acrossDays }

    /// How many more days are owed, from what has been counted so far.
    var daysRemaining: Int { max(0, Self.acrossDays - days) }

    /// The app came to the front, on a given day.
    ///
    /// The day is passed in rather than worked out here. Quiet's day turns at
    /// four in the morning and survives a change of time zone, and that rule
    /// lives in `QuietDay` and is tested there; a second, simpler copy of it in
    /// this file would be a second answer to the same question, and the two
    /// would disagree on exactly the nights the first one exists for.
    func enter(on day: Int) {
        note(day)
        guard since == nil else { return }
        since = uptime()
    }

    /// Count a day, unless it is the one already counted.
    private func note(_ day: Int) {
        guard lastDay != day else { return }
        lastDay = day
        days += 1
        defaults.set(day, forKey: Key.lastDay)
        defaults.set(days, forKey: Key.days)
    }

    /// Fold whatever has run since into the total, and keep counting.
    ///
    /// Absurd amounts are dropped rather than trusted, the same way the ledger
    /// drops them: a jump of that size is the shape of a clock going wrong, not
    /// of somebody looking at a screen.
    func bank() {
        guard let started = since else { return }
        let now = uptime()
        since = now
        let elapsed = now - started
        guard elapsed > 0, elapsed < Elapsed.plausible else { return }
        spent += elapsed
        defaults.set(spent, forKey: Key.spent)
    }

    /// The app went away. Banks what it owes and stops.
    func leave() {
        bank()
        since = nil
    }

    /// Said, and not said again for `gap` days. The minutes and the days start
    /// again, so the next question has to be earned as the first one was. The day it was asked on is kept as
    /// counted, so that it is not counted again as the first of the next three.
    func markAsked() {
        guard !asked else { return }
        askedOn = lastDay ?? 0
        spent = 0
        days = 0
        defaults.set(askedOn, forKey: Key.askedOn)
        defaults.set(spent, forKey: Key.spent)
        defaults.set(days, forKey: Key.days)
    }

    /// For a rehearsal, so that a scene photographs the same app every time.
    nonisolated static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.spent)
        defaults.removeObject(forKey: Key.asked)
        defaults.removeObject(forKey: Key.askedIn)
        defaults.removeObject(forKey: Key.askedOn)
        defaults.removeObject(forKey: Key.days)
        defaults.removeObject(forKey: Key.lastDay)
    }
}
