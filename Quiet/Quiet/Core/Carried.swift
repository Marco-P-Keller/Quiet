import Foundation

/// Everything that has to be the same on both phones, and the rule for what
/// happens when they disagree.
///
/// Sync is the one feature in this app that can hand somebody more time than
/// they agreed to, and it does it silently. Two phones with a thirty-minute
/// limit are an hour unless something says otherwise; a limit raised on one and
/// an old copy pushed from the other is a rule that can be walked backwards.
/// So the merge is not "the newest wins" with a shrug — it is written down
/// here, in one function, with the same asymmetry as the rest of the app:
///
/// **less time never has to wait, more time does.**
struct Carried: Codable, Equatable, Sendable {
    /// Counts up on every local change, so the two copies can say which was
    /// written later without trusting either phone's clock — which is the whole
    /// point of `MonotonicClock` and would be a strange thing to give up here.
    var version: Int

    /// The agreement: today's limit, any queued increase, when the last one was
    /// asked for, and the wait in force.
    var limit: LimitState

    /// The day the figures below belong to.
    var day: DayKey

    /// How much each phone has spent today, kept apart rather than added up.
    ///
    /// A single total cannot survive being merged. Two phones that each spend
    /// ten minutes have spent twenty, so the merge would have to add — and
    /// addition is not idempotent, so syncing twice would spend it twice. The
    /// answer is the oldest one in distributed computing: each phone only ever
    /// writes its own figure, merging takes the larger of each, and the day's
    /// total is the sum. Merge it as often as you like; the answer does not
    /// move.
    var byDevice: [String: TimeInterval]

    var spentToday: TimeInterval {
        byDevice.values.reduce(0, +)
    }

    /// Reconcile two copies.
    ///
    /// Commutative and idempotent — `merge(a, b) == merge(b, a)`, and merging a
    /// result back in changes nothing — because a sync that depended on which
    /// phone opened first would be a rule that could be shopped around.
    static func merge(_ mine: Carried, _ theirs: Carried) -> Carried {
        let tied = mine.version == theirs.version
        let newer = mine.version >= theirs.version ? mine : theirs
        let older = mine.version >= theirs.version ? theirs : mine

        // A different day is not a disagreement, it is one phone being behind.
        // The later day is the true one and it brings its own figures with it:
        // yesterday has nothing left to say about what has been spent today.
        if mine.day != theirs.day {
            let ahead = mine.day > theirs.day ? mine : theirs
            return Carried(
                version: newer.version,
                limit: agreement(newer.limit, older.limit, tied: tied),
                day: ahead.day,
                byDevice: ahead.byDevice
            )
        }

        var figures = mine.byDevice
        for (phone, seconds) in theirs.byDevice {
            figures[phone] = max(figures[phone] ?? 0, seconds)
        }

        return Carried(
            version: newer.version,
            limit: agreement(newer.limit, older.limit, tied: tied),
            day: mine.day,
            byDevice: figures
        )
    }

    /// The four fields of the agreement, each merged by its own rule.
    ///
    /// - `minutes` follows whichever copy was written last. It has to: a
    ///   perfectly legitimate increase, made yesterday on the other phone, would
    ///   otherwise be dragged back down for ever by a stale copy. Where neither
    ///   is newer — both phones wrote without having seen the other — the
    ///   smaller number wins, which is the only tiebreak that cannot give time
    ///   away.
    /// - `pending` takes the **smaller** of two queued increases, and a
    ///   cancellation wins outright: on the newer copy because it is the later
    ///   word, and on a tie because cancelling is asking for less, and asking
    ///   for less is always granted.
    /// - `lastIncrease` takes the **later** day. This is the one that closes the
    ///   obvious door: without it a stale copy could reset the weekly clock, and
    ///   a second increase could be had in the same week by opening the other
    ///   phone.
    /// - `cooldown` takes the **longer** wait, for exactly the reason the app
    ///   already gives when it is changed by hand: a request to be held to a
    ///   stricter rule is never refused.
    ///
    /// Every rule above is symmetric or decided by the version, so the result
    /// does not depend on which phone opened first — and merging a result back
    /// in changes nothing, which is what makes syncing twice safe.
    private static func agreement(
        _ newer: LimitState,
        _ older: LimitState,
        tied: Bool
    ) -> LimitState {
        var merged = newer
        if tied {
            merged.minutes = min(newer.minutes, older.minutes)
        }

        switch (newer.pending, older.pending) {
        case let (first?, second?):
            merged.pending = first.minutes <= second.minutes ? first : second
        case (nil, _):
            merged.pending = nil
        case let (first?, nil):
            // A queued increase the other phone has never heard of survives —
            // unless the two were written without seeing each other, where the
            // copy that queued nothing is the smaller answer.
            merged.pending = tied ? nil : first
        }

        merged.lastIncrease = [newer.lastIncrease, older.lastIncrease]
            .compactMap { $0 }
            .max()
        // Two copies that have never been given a wait keep not having one.
        // Filling in the default here instead would look harmless and is not:
        // the record would come back different from the one that was sent, so
        // every reconciliation would decide something had changed and write
        // again, for ever, over a field nobody touched.
        merged.cooldown = newer.cooldown == nil && older.cooldown == nil
            ? nil
            : max(newer.cooldownDays, older.cooldownDays)
        return merged
    }
}

/// The name this phone writes its own figure under.
///
/// Made once and kept in the ordinary place preferences live, not in the
/// keychain — and that is deliberate. A phone that is wiped and set up again
/// comes back under a new name, so its old figure stays in the record and the
/// day looks *more* spent than it is. That is the direction to be wrong in: an
/// identity that survived a wipe would let somebody reset the count by
/// reinstalling, which is the whole thing the keychain is there to prevent.
enum ThisPhone {
    private static let key = "quiet.phone.name"

    static func name(in defaults: UserDefaults = .standard) -> String {
        if let known = defaults.string(forKey: key) { return known }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: key)
        return fresh
    }
}

/// Somewhere a copy of `Carried` can be kept where the other phone can see it.
///
/// A protocol because the merge rule above is worth testing without a network,
/// an iCloud account, or a second phone — and because a sync that only ever ran
/// on real hardware would be a sync nobody could argue about.
@MainActor
protocol Cloud: AnyObject {
    /// What is up there, or `nil` if there is nothing yet or nobody to ask.
    /// Never throws: a phone with no iCloud account, or no signal, is a phone
    /// that works exactly as it did before this feature existed.
    func fetch() async -> Carried?

    /// Put this copy up, replacing whatever was there.
    func put(_ carried: Carried) async

    /// Take it down.
    ///
    /// "Forget everything" has to mean everything. A copy left in iCloud would
    /// be seeded straight back onto the phone by the next device to open, which
    /// would turn a promise into a delay.
    func forget() async
}
