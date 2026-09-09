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
/// - Once. Ever. iOS caps the prompt at three a year on its own, but a rule
///   that leans on somebody else's cap is a rule that would ask every day if
///   the cap were lifted.
///
/// The one shot is not spent more often for having waited — it is spent on
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
    static let asked = "quiet.applause.asked"
    static let days = "quiet.applause.days"
    static let lastDay = "quiet.applause.lastday"
}

@MainActor
@Observable
final class Applause {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let uptime: () -> TimeInterval

    /// What it takes.
    static let earned: TimeInterval = 5 * 60

    /// And on how many separate days. Three rather than two because two is
    /// "came back once", which a person does out of curiosity; three is a
    /// habit forming, and a habit forming is the thing being asked about.
    static let acrossDays = 3

    /// Time the app has been on screen, across every launch so far.
    private(set) var spent: TimeInterval

    /// How many separate days the app has been opened on.
    private(set) var days: Int

    /// The last day counted, so that opening the app nine times before lunch
    /// is one day and not nine. Stored as `DayKey`'s ordinal — the day Quiet
    /// means, which turns at four in the morning, rather than the calendar's.
    private(set) var lastDay: Int?

    /// Whether the question has already been put.
    private(set) var asked: Bool

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
        self.asked = defaults.bool(forKey: Key.asked)
        self.days = defaults.integer(forKey: Key.days)
        // `object(forKey:)` rather than `integer(forKey:)`: a missing key reads
        // as zero, and zero is a real ordinal. Nobody will open this app on the
        // day it stands for, but a rule that is only right because the date is
        // implausible is a rule that is wrong.
        self.lastDay = defaults.object(forKey: Key.lastDay) as? Int
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

    /// Said once, and never unsaid.
    func markAsked() {
        guard !asked else { return }
        asked = true
        defaults.set(true, forKey: Key.asked)
    }

    /// For a rehearsal, so that a scene photographs the same app every time.
    nonisolated static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.spent)
        defaults.removeObject(forKey: Key.asked)
        defaults.removeObject(forKey: Key.days)
        defaults.removeObject(forKey: Key.lastDay)
    }
}
