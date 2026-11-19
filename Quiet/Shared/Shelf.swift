import Foundation

/// The one place Quiet and its two Screen Time extensions can both reach.
///
/// The extensions run in processes of their own, at moments the app does not
/// choose — a minute of Instagram passing at eleven at night, four o'clock
/// arriving — and the only thing the three share is this app group. So what
/// they say to each other is written down here, small and plain:
///
/// - the app writes the **terms**: the limit, and how much of today Quiet
///   itself has spent;
/// - the extension writes the **tally**: how many minutes the Instagram app
///   has had today, as Screen Time reports them;
/// - either writes **closed until**, the moment the Instagram app opens again.
///
/// Nothing on this shelf leaves the phone. It is the same kind of storage as
/// the app's own preferences, in a suite the two halves happen to share.
enum Shelf {
    static let group = "group.com.connexa.quiet"

    /// The shared suite, or — in a test, or on a build somebody signed without
    /// the group — the app's own, so that nothing here can fail loudly.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: group) ?? .standard
    }

    enum Key {
        static let terms = "quiet.shelf.terms"
        static let tally = "quiet.shelf.tally"
        static let reach = "quiet.shelf.reach"
        static let closedUntil = "quiet.shelf.closedUntil"
        static let watched = "quiet.shelf.watched"
        static let trouble = "quiet.shelf.trouble"
    }

    static func load<Value: Decodable>(_ type: Value.Type, _ key: String, in defaults: UserDefaults = defaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    static func save<Value: Encodable>(_ value: Value?, _ key: String, in defaults: UserDefaults = defaults) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}

/// What the app tells the extension: the rule, and what Quiet has already
/// spent of it today.
///
/// "Spent in Quiet" means everything the app's own ledger holds *except* what
/// came from the Instagram app — Quiet's own screen, and the reader's other
/// devices if the limit is carried between them. The Instagram app's share is
/// the extension's to count; writing it back here would count it twice.
struct Terms: Codable, Equatable, Sendable {
    var limit: LimitState
    var day: DayKey
    var spentInQuiet: TimeInterval
}

/// What the extension tells the app: how far into the Instagram app today has
/// gone, in whole minutes.
///
/// Screen Time does not hand out a running total. It says "this much has
/// passed" when a threshold is crossed, and Quiet sets the thresholds a minute
/// apart (see `Milestones`), so the tally is the highest one crossed today.
struct Tally: Codable, Equatable, Sendable {
    var day: DayKey
    var minutes: Int

    /// The tally after a threshold of `minutes` was crossed on `day`.
    ///
    /// Only ever upwards within a day. Screen Time repeats thresholds it has
    /// already passed whenever monitoring is started again — that is what
    /// `includesPastActivity` asks it to do — and they arrive in no promised
    /// order. A new day starts from whatever it reports.
    func reaching(_ minutes: Int, on day: DayKey) -> Tally {
        guard day == self.day else { return Tally(day: day, minutes: minutes) }
        return Tally(day: day, minutes: max(self.minutes, minutes))
    }
}

/// Whether the day is over, counting both doors into Instagram.
enum Verdict {
    /// The one sum the whole feature rests on: Quiet's minutes and the
    /// Instagram app's minutes, against the one limit.
    ///
    /// Terms from an earlier day count for nothing — that is a day Quiet was
    /// not opened yet — and a tally from an earlier day likewise. A limit with
    /// an increase that has come due is read as the increased one, exactly as
    /// the app will read it when it is next opened.
    static func isOver(tally: Tally?, terms: Terms?, today: DayKey) -> Bool {
        guard let terms else { return false }
        let limit = LimitPolicy.rolled(terms.limit, to: today).minutes
        let inQuiet = terms.day == today ? terms.spentInQuiet : 0
        let inApp = tally.map { $0.day == today ? TimeInterval($0.minutes) * 60 : 0 } ?? 0
        return inQuiet + inApp >= TimeInterval(limit) * 60
    }
}

/// The minutes at which Screen Time is asked to report back.
///
/// A minute apart up to an hour, which makes the Instagram app close within a
/// minute of the limit. Past an hour the marks spread out so there are never
/// more than sixty of them: a four-hour limit is checked every four minutes,
/// and the curtain on the app arrives up to three minutes late. Nobody with a
/// four-hour limit is being held to the minute.
enum Milestones {
    static let most = 60

    static func marks(upTo top: Int) -> [Int] {
        guard top > 0 else { return [] }
        let step = max(1, Int((Double(top) / Double(most)).rounded(.up)))
        var marks = Array(stride(from: step, through: top, by: step))
        if marks.last != top { marks.append(top) }
        return marks
    }

    private static let prefix = "quiet.minute."

    static func name(_ minutes: Int) -> String { prefix + String(minutes) }

    static func minutes(_ name: String) -> Int? {
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    /// The highest mark worth setting: the larger of the limit in force and
    /// one waiting to take over, so that tomorrow's bigger number is already
    /// being watched for when tomorrow comes.
    static func top(for limit: LimitState) -> Int {
        max(limit.minutes, limit.pending?.minutes ?? 0)
    }
}

/// How far the limit reaches beyond Quiet: which other apps it also counts and
/// closes.
///
/// The same asymmetry as everything else in the app, applied to a new
/// question. **Reaching further is free** — counting one more app, or starting
/// to count at all, applies at once. **Reaching less waits**: taking an app
/// out, or switching the whole thing off, applies from the next day. Otherwise
/// this would be the one setting you could loosen with the curtain already
/// down, and the app would have built a door around its own rule.
///
/// Generic over what a selection is, because the real one is a Screen Time
/// type made of opaque tokens that no test can build. `covers` says whether one
/// selection includes everything another one does.
struct Reach<Selection: Codable & Equatable>: Codable, Equatable {
    /// What the limit covers today. `nil` is Quiet alone.
    var current: Selection?
    /// A narrower reach that has been asked for, and when it takes over.
    var narrowing: Narrowing?

    struct Narrowing: Codable, Equatable {
        var to: Selection?
        var from: DayKey
    }

    init(current: Selection? = nil, narrowing: Narrowing? = nil) {
        self.current = current
        self.narrowing = narrowing
    }

    /// Bring the reach up to `today`, letting a narrowing that has come due
    /// take over. Idempotent.
    func rolled(to today: DayKey) -> Reach {
        guard let narrowing, narrowing.from <= today else { return self }
        return Reach(current: narrowing.to, narrowing: nil)
    }

    /// Ask for a different reach.
    ///
    /// Anything that covers at least what is covered now applies at once and
    /// cancels a narrowing that was waiting — asking to keep what you have is
    /// asking for more than the narrowing would have left. Anything less waits
    /// for tomorrow.
    func requesting(
        _ wanted: Selection?,
        today: DayKey,
        covers: (Selection?, Selection?) -> Bool
    ) -> Reach {
        let now = rolled(to: today)
        if covers(wanted, now.current) {
            return Reach(current: wanted, narrowing: nil)
        }
        return Reach(current: now.current, narrowing: Narrowing(to: wanted, from: today.next))
    }
}
