import Foundation
import Observation

/// When, if ever, to ask what somebody thinks of the app.
///
/// Asking is a small rudeness, so it gets exactly one shot and it has to earn
/// it. Two conditions, and both matter:
///
/// - Five minutes of the app actually in front of somebody. Not five minutes
///   since it was installed — an app can sit unopened for a week — and not one
///   long sitting either, because Quiet is built to be used in short ones and a
///   rule that only fires in a long sitting would fire for the people using it
///   worst.
/// - Once. Ever. iOS caps the prompt at three a year on its own, but a rule
///   that leans on somebody else's cap is a rule that would ask every day if
///   the cap were lifted.
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
}

@MainActor
@Observable
final class Applause {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let uptime: () -> TimeInterval

    /// What it takes.
    static let earned: TimeInterval = 5 * 60

    /// Time the app has been on screen, across every launch so far.
    private(set) var spent: TimeInterval

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
    }

    /// How much longer, from what has been banked so far.
    var remaining: TimeInterval { max(0, Self.earned - spent) }

    /// Whether the moment has come. Read after `bank()`.
    var isDue: Bool { !asked && spent >= Self.earned }

    /// The app came to the front.
    func enter() {
        guard since == nil else { return }
        since = uptime()
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
    }
}
