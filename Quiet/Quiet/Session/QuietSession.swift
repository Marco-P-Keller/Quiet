import Foundation
import Observation

/// The running state of the app: which screen is showing, how much of today is
/// left, and what the limit currently is.
///
/// Time is counted from the device's uptime clock, never from differences
/// between wall-clock readings, so moving the date around changes nothing about
/// how many minutes have been spent. Only foreground time counts, and only while
/// Instagram is actually on screen — not while the panel is open, not while the
/// phone is locked, not while the app sits in the background.
@MainActor
@Observable
final class QuietSession {
    enum Screen: Equatable {
        /// First run: no limit has been chosen yet.
        case setup
        /// Instagram.
        case browsing
        /// Today's time is gone.
        case spent
    }

    private(set) var screen: Screen = .setup
    private(set) var limit = LimitState(minutes: 20)
    private(set) var ledger: UsageLedger
    private(set) var notice: Notice?

    /// The day the limit was first chosen. `nil` on a fresh install.
    private(set) var setupDay: DayKey?

    /// The day everything is to be thrown away, if somebody has asked.
    ///
    /// `nil` almost always, which is the whole point: this is not a feature
    /// anybody uses twice. See `askToBeForgotten`.
    private(set) var forgetOn: DayKey?

    /// Bound to the panel's presentation. While the panel is up, the clock stops:
    /// time spent deciding how much time you want is not time on Instagram.
    var isPanelShowing = false {
        didSet { syncCounting() }
    }

    /// Bound to the search sheet. The clock stops here too: looking for somebody
    /// is not the same as reading about them.
    var isSearchShowing = false {
        didSet { syncCounting() }
    }

    private let store: any StateStore
    private let clock: MonotonicClock
    private let calendar: Calendar

    /// The handful of things that are settings rather than promises.
    ///
    /// Handed in rather than built here, and built once in `QuietApp` rather
    /// than once per view, because two objects now read it — this one, for
    /// whether to say anything as the day runs out, and the panel, for the
    /// shape of the row. Two copies of a preference are two preferences, and
    /// the one that is wrong is whichever one the reader is not looking at.
    let preferences: Preferences

    /// What calls back once a second while the app is on screen, and the
    /// reading of elapsed time it is counted against.
    ///
    /// Both are handed in for the same reason: everything that only happens
    /// inside a tick — the ledger accruing, the two warnings, the curtain —
    /// used to be testable only by waiting, which means it was not tested.
    private let heartbeat: any Heartbeat
    private let uptime: () -> TimeInterval

    private var isForeground = false
    private var isBeating = false
    private var lastSample: TimeInterval?
    private var unsavedSeconds: TimeInterval = 0
    private var announced: Set<Int> = []
    private var noticeCount = 0

    /// How often foreground time is folded into the ledger, and how much may
    /// accumulate before it is written down. Short enough that a crash costs a
    /// few seconds; long enough not to touch the keychain constantly.
    private static let sampleInterval: TimeInterval = 1
    private static let flushInterval: TimeInterval = 5

    /// Minutes remaining at which the app says something. Twice, quietly, and
    /// then not again.
    static let warnings = [5, 1]

    init(
        store: any StateStore,
        clock: MonotonicClock,
        preferences: Preferences = Preferences(),
        calendar: Calendar = .current,
        heartbeat: any Heartbeat = RunLoopHeartbeat(),
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.store = store
        self.clock = clock
        self.preferences = preferences
        self.calendar = calendar
        self.heartbeat = heartbeat
        self.uptime = uptime
        ledger = UsageLedger(day: DayKey(clock.now, calendar: calendar))
    }

    // MARK: - Lifecycle

    /// Load what was saved and decide which screen to show. Safe to call twice.
    func start() {
        setupDay = store.load(DayKey.self, for: .setupDay)
        forgetOn = store.load(DayKey.self, for: .forgetOn)
        if let saved = store.load(LimitState.self, for: .limit) {
            limit = saved
        }
        if let saved = store.load(UsageLedger.self, for: .usage) {
            ledger = saved
        }
        guard setupDay != nil else {
            screen = .setup
            return
        }
        forgetIfDue()
        guard setupDay != nil else {
            screen = .setup
            return
        }
        rollIfNeeded()
        evaluateScreen()
        syncCounting()
    }

    /// Finish first run with the chosen limit. This one applies immediately: the
    /// waiting rules exist to protect a decision already made, and there is
    /// nothing yet to protect.
    func completeSetup(minutes: Int) {
        let clamped = min(max(minutes, LimitPolicy.allowed.lowerBound), LimitPolicy.allowed.upperBound)
        limit = LimitState(minutes: clamped)
        ledger = UsageLedger(day: today, endsAt: today.end(calendar: calendar))
        setupDay = today
        store.save(today, for: .setupDay)
        persist()
        screen = .browsing
        syncCounting()
    }

    /// Called from the scene phase.
    func setForeground(_ active: Bool) {
        guard active != isForeground else { return }
        isForeground = active
        if active {
            rollIfNeeded()
            evaluateScreen()
        } else {
            checkpoint()
        }
        syncCounting()
    }

    // MARK: - The day

    var today: DayKey { DayKey(clock.now, calendar: calendar) }

    /// Seconds left today.
    var remaining: TimeInterval { ledger.remaining(limitMinutes: limit.minutes) }

    /// When today's allowance comes back.
    ///
    /// The ending the running day was given, not one recomputed now — otherwise
    /// the curtain would promise a reset that changes the moment somebody
    /// crosses a border.
    var resetsAt: Date { ledger.endsAt ?? today.end(calendar: calendar) }

    /// True when the device clock sits behind time the app has already seen.
    var isClockRewound: Bool { clock.isRewound }

    /// True when the device clock sits ahead of a time Instagram's own servers
    /// vouched for. The mirror image of a rewind, and until there was an anchor
    /// to compare against it was the one attack the app could not see at all.
    var isClockAdvanced: Bool { clock.isAdvanced }

    /// Instagram's servers said what time it is.
    ///
    /// Handed straight through to the clock. The session does not decide
    /// anything about it — the point of putting the rule in one object is that
    /// there is one place to read to know what the app believes and why.
    func vouchForTime(_ instant: Date) {
        clock.vouch(instant)
    }

    /// False once the store has refused a write. At that point nothing the app
    /// is told survives a relaunch — the limit least of all — and the only
    /// honest thing to do is stop implying otherwise.
    ///
    /// Mirrored rather than read through to the store, which is a plain class:
    /// reading it directly meant SwiftUI never learned that it had changed, and
    /// the red banner waited for some unrelated redraw to appear.
    private(set) var isMemoryReliable = true

    // MARK: - Changing the limit

    /// What would happen if this number were asked for, without asking for it.
    /// The change screen uses this to describe the consequence before anyone
    /// commits to it, and because it runs the same rule, the description cannot
    /// drift from what the button does.
    func preview(_ minutes: Int) -> Result<(state: LimitState, change: LimitChange), LimitRefusal> {
        if let refusal = guardRail(minutes) { return .failure(refusal) }
        return LimitPolicy.request(minutes, from: limit, today: today)
    }

    @discardableResult
    func requestLimit(_ minutes: Int) -> Result<LimitChange, LimitRefusal> {
        if let refusal = guardRail(minutes) { return .failure(refusal) }

        switch LimitPolicy.request(minutes, from: limit, today: today) {
        case let .success((state, change)):
            limit = state
            persist()
            // A smaller limit can land below what has already been spent. Ending
            // the day right then is the honest reading of the request.
            evaluateScreen()
            syncCounting()
            return .success(change)
        case let .failure(refusal):
            return .failure(refusal)
        }
    }

    /// Ask for a different wait between increases.
    ///
    /// Longer is free; shorter is subject to the wait it is trying to shorten,
    /// and spends it. See `LimitPolicy.requestCooldown`.
    @discardableResult
    func requestCooldown(_ days: Int) -> Result<Int, LimitRefusal> {
        // A clock that is not where it should be cannot buy a shorter wait,
        // for the same reason it cannot buy a larger limit. A longer one is
        // never refused: nothing about a stricter rule needs a trustworthy
        // date to be safe.
        if days < limit.cooldownDays {
            if isClockRewound { return .failure(.clockRewound) }
            if isClockAdvanced { return .failure(.clockAdvanced) }
        }

        switch LimitPolicy.requestCooldown(days, from: limit, today: today) {
        case let .success(state):
            limit = state
            persist()
            return .success(days)
        case let .failure(refusal):
            return .failure(refusal)
        }
    }

    /// A clock that is not where it should be only threatens increases. Asking
    /// for less is always allowed, whatever the date says.
    ///
    /// "Less" is measured against everything already agreed to, today's limit
    /// and any increase already queued for tomorrow. Measuring it against today
    /// alone refused a revision of a queued increase *downward* — a reduction —
    /// while the screen was saying the limit could go down but not up.
    ///
    /// Both directions count. A rewind was always caught here; a jump forward
    /// used to arrive as a perfectly ordinary week having passed, which is the
    /// whole of what the weekly rule is made of.
    private func guardRail(_ minutes: Int) -> LimitRefusal? {
        let agreed = max(limit.minutes, limit.pending?.minutes ?? limit.minutes)
        guard minutes > agreed else { return nil }
        if isClockRewound { return .clockRewound }
        if isClockAdvanced { return .clockAdvanced }
        return nil
    }

    // MARK: - Letting go

    /// Ask Quiet to forget everything, after the wait currently in force.
    ///
    /// The limit lives in the keychain because it has to outlive the app being
    /// deleted — that is the promise, and it is said plainly during setup. The
    /// consequence nobody wrote down is that there was no way out at all. The
    /// only exit was for somebody to know that a keychain exists, and to go and
    /// find it, which is not an exit, it is a trap with documentation.
    ///
    /// So there is a door, and it is the same shape as every other door here:
    /// it opens slowly. The wait is whatever the wait between increases is,
    /// which means it cannot be shortened in the moment either — shortening
    /// that number is itself subject to it.
    ///
    /// The Instagram session is not part of this. Signing out is its own
    /// button and always was, and bundling the two would mean somebody asking
    /// to be released from a rule was also, a week later and without being
    /// asked again, logged out.
    @discardableResult
    func askToBeForgotten() -> DayKey {
        let day = today.adding(days: limit.cooldownDays)
        forgetOn = day
        store.save(day, for: .forgetOn)
        checkMemory()
        return day
    }

    /// Change your mind. Free, at any moment before the day comes, because
    /// changing your mind about being released is asking to be held to the
    /// rule — and the app never stands in the way of that.
    func keepRemembering() {
        guard forgetOn != nil else { return }
        forgetOn = nil
        store.remove(.forgetOn)
    }

    /// Throw it all away, if the day has come.
    ///
    /// Every key, including the mark the clock keeps, because "everything"
    /// that quietly kept one thing would be a worse promise than not offering
    /// this at all. What is left is an app that has never been run.
    private func forgetIfDue() {
        guard let forgetOn, today >= forgetOn else { return }
        for key in StoreKey.allCases { store.remove(key) }
        self.forgetOn = nil
        setupDay = nil
        limit = LimitState(minutes: 20)
        ledger = UsageLedger(day: today, endsAt: today.end(calendar: calendar))
        announced.removeAll()
        notice = nil
        screen = .setup
    }

    // MARK: - Notices

    func report(_ surface: BlockedSurface) {
        show(surface.message)
    }

    func show(_ text: String) {
        noticeCount += 1
        notice = Notice(text: text, token: noticeCount)
    }

    func dismissNotice(token: Int) {
        if notice?.token == token { notice = nil }
    }

    // MARK: - Counting

    /// Whether the clock should be running at all.
    ///
    /// Wider than `shouldCount` on purpose. Somebody who reaches the curtain
    /// and leaves the app open overnight still deserves their morning: without
    /// a tick behind the curtain, nothing notices four o'clock and the day
    /// never turns until the app is backgrounded and brought back.
    private var shouldTick: Bool {
        isForeground && screen != .setup
    }

    /// Whether the time being spent is time on Instagram.
    private var shouldCount: Bool {
        shouldTick && screen == .browsing && !isPanelShowing && !isSearchShowing
    }

    /// Start or stop the heartbeat to match `shouldTick`. Never reentrant:
    /// nothing it calls changes `screen`, `isForeground`, or either sheet's
    /// flag.
    private func syncCounting() {
        if shouldTick {
            guard !isBeating else { return }
            isBeating = true
            lastSample = uptime()
            heartbeat.start(every: Self.sampleInterval) { [weak self] in
                self?.tick()
            }
        } else {
            guard isBeating else { return }
            isBeating = false
            heartbeat.stop()
            accrue()
            lastSample = nil
            flush()
            clock.flush()
        }
    }

    private func tick() {
        if shouldCount {
            accrue()
            if !ledger.isSpent(limitMinutes: limit.minutes) {
                announceIfNeeded()
            }
        } else {
            // The clock runs, but nothing is being spent. Dropping the sample
            // is what makes the panel and the curtain free.
            lastSample = nil
            rollIfNeeded()
        }
        evaluateScreen()
        syncCounting()
    }

    /// Fold elapsed foreground time into the ledger. Accounting only: it never
    /// changes which screen is showing.
    private func accrue() {
        let now = uptime()
        defer { lastSample = now }
        guard let previous = lastSample else { return }
        let elapsed = now - previous

        rollIfNeeded()
        ledger.add(elapsed)
        unsavedSeconds += elapsed
        if unsavedSeconds >= Self.flushInterval {
            flush()
        }
    }

    /// Move to a new day if one has begun, applying any limit change that was
    /// waiting for it.
    private func rollIfNeeded() {
        let day = today
        guard day != ledger.day else { return }
        // Before the new day is opened, in case the new day is the one on
        // which there is nothing left to open it for.
        forgetIfDue()
        guard setupDay != nil else { return }
        // A different day is not the same thing as a day that has passed. The
        // date changes the instant a time zone does, and a time zone is two taps
        // away; the ending this day was given when it began does not move.
        guard ledger.hasEnded(by: clock.now) else { return }
        ledger.roll(to: day, endingAt: day.end(calendar: calendar))
        limit = LimitPolicy.rolled(limit, to: day)
        announced.removeAll()
        persist()
    }

    private func evaluateScreen() {
        // Guarded on whether setup has happened, not on which screen is
        // showing. Guarding on the screen looked equivalent and was not: at
        // launch the screen still holds its initial `.setup` value, so this
        // returned early every time and a returning user was shown the
        // onboarding question forever.
        guard setupDay != nil else { return }
        let target: Screen = ledger.isSpent(limitMinutes: limit.minutes) ? .spent : .browsing
        guard target != screen else { return }
        screen = target
        if target == .spent {
            notice = nil
            flush()
        }
    }

    /// Which warnings have come due, given what is left and what has already
    /// been said.
    ///
    /// Pulled out as a function of its arguments because the first version was
    /// wrong in a way that reading it did not reveal: it took the first match
    /// in `[5, 1]`, which is always 5, so with one minute left the app said
    /// "5 minutes left" and "One minute left." could never be reached at all.
    static func warningsDue(minutesLeft: Int, alreadySaid: Set<Int>) -> Set<Int> {
        Set(warnings.filter { minutesLeft <= $0 && !alreadySaid.contains($0) })
    }

    private func announceIfNeeded() {
        guard preferences.saysWhatIsLeft else { return }
        let due = Self.warningsDue(
            minutesLeft: Int(ceil(remaining / 60)),
            alreadySaid: announced
        )
        guard let threshold = due.min() else { return }
        // Anything less urgent that came due in the same breath is spent too:
        // coming back from the background at one minute should say one thing,
        // and it should be the urgent one.
        announced.formUnion(due)
        show(String(localized: "\(threshold) minutes left."))
    }

    // MARK: - Persistence

    /// Nothing is written while there is nothing to be written about.
    ///
    /// Before setup there is no limit and no day; after being forgotten there
    /// is neither again. Both used to reach here anyway — the ticker stops a
    /// beat after the screen changes, and the beat in between was enough to
    /// write today's total back out on top of an app that had just been
    /// emptied.
    private var hasSomethingToRemember: Bool { setupDay != nil }

    private func flush() {
        unsavedSeconds = 0
        guard hasSomethingToRemember else { return }
        store.save(ledger, for: .usage)
        checkMemory()
    }

    private func persist() {
        unsavedSeconds = 0
        guard hasSomethingToRemember else { return }
        store.save(limit, for: .limit)
        store.save(ledger, for: .usage)
        checkMemory()
    }

    /// Pulls the store's health across into observable state, after every write
    /// that could have been the one it turned down.
    private func checkMemory() {
        if isMemoryReliable != store.isWritable {
            isMemoryReliable = store.isWritable
        }
    }

    /// Called when the app is about to lose the foreground, so nothing is lost if
    /// it is never resumed.
    func checkpoint() {
        accrue()
        flush()
        clock.flush()
    }
}
