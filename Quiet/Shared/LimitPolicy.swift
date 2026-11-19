import Foundation

/// How much time is allowed in a day, and what may change it.
struct LimitState: Codable, Equatable, Sendable {
    /// Minutes allowed today.
    var minutes: Int
    /// A larger limit that has been asked for and takes effect on a later day.
    var pending: PendingChange?
    /// The day the most recent increase was *asked for*. The weekly cooldown
    /// runs from the decision, not from the day it takes effect.
    var lastIncrease: DayKey?

    /// How long the wait between increases is, in days.
    ///
    /// A week by default, and a week is the whole argument the app was built
    /// to win — but a week is also somebody's guess, and for a reader who
    /// knows themselves it is the wrong guess in a knowable direction. So the
    /// number can be moved, under the same asymmetry as everything else here:
    /// **longer is free, shorter waits**. Asking to be held to a stricter rule
    /// is a thing the app should never stand in the way of; asking to be held
    /// to a looser one is exactly the decision that must not be available in
    /// the moment it starts to bite.
    ///
    /// Optional because states written by earlier versions do not carry it,
    /// and a synthesised decoder throws for a missing key rather than reaching
    /// for a default. Read through `cooldownDays`, never directly.
    var cooldown: Int?

    /// The wait in force, with the default filled in.
    var cooldownDays: Int { cooldown ?? LimitPolicy.defaultCooldownDays }

    init(
        minutes: Int,
        pending: PendingChange? = nil,
        lastIncrease: DayKey? = nil,
        cooldown: Int? = nil
    ) {
        self.minutes = minutes
        self.pending = pending
        self.lastIncrease = lastIncrease
        self.cooldown = cooldown
    }
}

struct PendingChange: Codable, Equatable, Sendable {
    var minutes: Int
    /// The first day the new limit applies.
    var effective: DayKey
}

/// When a requested change takes hold.
enum LimitChange: Equatable, Sendable {
    /// Applies to the rest of today.
    case now(Int)
    /// Applies from the given day onward.
    case on(DayKey, Int)
}

/// Why a change was turned down.
enum LimitRefusal: Equatable, Error, Sendable {
    /// The requested number is the limit already in force.
    case unchanged
    /// An increase was asked for inside the weekly cooldown.
    case tooSoon(nextAllowed: DayKey)
    /// Outside the range the app supports.
    case outOfRange(ClosedRange<Int>)
    /// The device clock is behind time Quiet has already seen.
    case clockRewound
    /// The device clock is ahead of a time Instagram's own servers vouched for.
    case clockAdvanced
}

/// The rule that makes Quiet worth installing.
///
/// Most screen-time limits fail for one reason: they can be lifted at the exact
/// moment they start to bite, by the person least able to judge. Quiet's limit
/// is deliberately asymmetric.
///
/// * **Asking for less is free.** It applies at once and costs nothing. The app
///   should never stand between someone and a smaller number.
/// * **Asking for more waits.** An increase takes effect on the *next* day, and
///   only one increase is possible per week. Both halves matter: the weekly
///   cooldown makes the decision rare, and the overnight delay makes sure it is
///   never made mid-scroll, with the curtain already down.
///
/// Everything here is a pure function of state and today's date, so the rule can
/// be read in one sitting and tested without an app around it.
enum LimitPolicy {
    /// The supported range. Below five minutes the app is a joke; above four
    /// hours it is not a limit.
    static let allowed: ClosedRange<Int> = 5...240

    /// Days that must pass between one increase and the next, unless somebody
    /// has asked for more.
    static let defaultCooldownDays = 7

    /// The waits the app offers. Round numbers a person would say out loud,
    /// and nothing below the default: the choice on offer is how much stricter
    /// to be, not how much looser.
    static let cooldowns = [7, 14, 30]

    /// Bring state up to date for `today`, applying any change that has come due.
    /// Idempotent, and safe to call on every launch.
    static func rolled(_ state: LimitState, to today: DayKey) -> LimitState {
        guard let pending = state.pending, pending.effective <= today else { return state }
        var next = state
        next.minutes = pending.minutes
        next.pending = nil
        return next
    }

    /// Ask for a new daily limit.
    static func request(
        _ minutes: Int,
        from state: LimitState,
        today: DayKey
    ) -> Result<(state: LimitState, change: LimitChange), LimitRefusal> {
        guard allowed.contains(minutes) else {
            return .failure(.outOfRange(allowed))
        }

        if minutes == state.minutes && state.pending == nil {
            return .failure(.unchanged)
        }

        // Less than today's limit — or a cancellation of a queued increase.
        // Applies immediately. Note that this deliberately leaves `lastIncrease`
        // alone: if a reduction reset the weekly clock, anyone could raise the
        // limit, drop it the next day, and raise it again.
        if minutes <= state.minutes {
            var next = state
            next.minutes = minutes
            next.pending = nil
            return .success((next, .now(minutes)))
        }

        // More than today's limit, but less than an increase already queued.
        // Revising a decision downward before it takes effect is still asking
        // for less, so it does not restart the cooldown.
        if let pending = state.pending, minutes < pending.minutes {
            var next = state
            next.pending = PendingChange(minutes: minutes, effective: pending.effective)
            return .success((next, .on(pending.effective, minutes)))
        }

        // A genuine increase.
        if let last = state.lastIncrease {
            let nextAllowed = last.adding(days: state.cooldownDays)
            guard today >= nextAllowed else {
                return .failure(.tooSoon(nextAllowed: nextAllowed))
            }
        }

        let effective = today.next
        var next = state
        next.pending = PendingChange(minutes: minutes, effective: effective)
        next.lastIncrease = today
        return .success((next, .on(effective, minutes)))
    }

    /// The first day an increase would be accepted again, or `nil` if one would
    /// be accepted now.
    static func nextIncreaseDay(_ state: LimitState, today: DayKey) -> DayKey? {
        guard let last = state.lastIncrease else { return nil }
        let nextAllowed = last.adding(days: state.cooldownDays)
        return today >= nextAllowed ? nil : nextAllowed
    }

    /// Ask for a different wait between increases.
    ///
    /// The same asymmetry as the limit, for the same reason and with one extra
    /// turn of the screw. A **longer** wait applies at once: it is a request to
    /// be held to a stricter rule, and the app has no business slowing that
    /// down. A **shorter** one is a loosening, so it is subject to the wait
    /// currently in force — and it consumes that wait, exactly as an increase
    /// does, because otherwise the way around the weekly rule would be to
    /// shorten the weekly rule.
    ///
    /// Reading it the other way makes the point: without this, the cooldown
    /// would be the one number in the app you could lower in the moment it
    /// started to bite, which is precisely the thing the app exists not to
    /// have.
    static func requestCooldown(
        _ days: Int,
        from state: LimitState,
        today: DayKey
    ) -> Result<LimitState, LimitRefusal> {
        guard cooldowns.contains(days) else {
            return .failure(.outOfRange(cooldowns.first!...cooldowns.last!))
        }
        guard days != state.cooldownDays else { return .failure(.unchanged) }

        var next = state
        if days > state.cooldownDays {
            next.cooldown = days
            return .success(next)
        }

        // Shorter. Subject to the wait it is trying to shorten.
        if let last = state.lastIncrease {
            let allowed = last.adding(days: state.cooldownDays)
            guard today >= allowed else {
                return .failure(.tooSoon(nextAllowed: allowed))
            }
        }
        next.cooldown = days
        next.lastIncrease = today
        return .success(next)
    }
}
