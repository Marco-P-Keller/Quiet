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

    /// What puts the daily reminder on the phone. See `Appointment`.
    private let ringer: any Ringer

    /// Where the agreement is left for this reader's other phones, and the name
    /// this one writes its own figures under. See `Carried`.
    private let cloud: any Cloud
    private let phone: String

    /// The last agreement reconciled with those phones, as far as this one
    /// knows. Its version is what lets two copies say which was written later.
    private var carried: Carried?

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

    /// Two of these are `nil` rather than a real default, and it is not a
    /// matter of taste.
    ///
    /// A default argument is evaluated at the call site, in whatever context
    /// the caller happens to be in — and that context is not this type's. Both
    /// `Preferences` and `RunLoopHeartbeat` belong to the main actor, so
    /// writing them as defaults asks for them to be built somewhere that is not
    /// allowed to build them, which the compiler refuses. Built in the body
    /// instead, which is isolated, and `nil` means "whichever the app would
    /// have used".
    init(
        store: any StateStore,
        clock: MonotonicClock,
        preferences: Preferences? = nil,
        calendar: Calendar = .current,
        heartbeat: (any Heartbeat)? = nil,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        ringer: (any Ringer)? = nil,
        cloud: (any Cloud)? = nil,
        phone: String? = nil
    ) {
        self.store = store
        self.clock = clock
        self.preferences = preferences ?? Preferences()
        self.calendar = calendar
        self.heartbeat = heartbeat ?? RunLoopHeartbeat()
        self.uptime = uptime
        self.ringer = ringer ?? SystemRinger()
        self.cloud = cloud ?? CloudMirror()
        self.phone = phone ?? ThisPhone.name()
        ledger = UsageLedger(day: DayKey(clock.now, calendar: calendar))
    }

    // MARK: - Lifecycle

    /// Load what was saved and decide which screen to show. Safe to call twice.
    func start() {
        setupDay = store.load(DayKey.self, for: .setupDay)
        forgetOn = store.load(DayKey.self, for: .forgetOn)
        carried = store.load(Carried.self, for: .carried)
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
        mindTheAppointment()
        Task { await catchUp() }
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
        noteLocalChange()
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
            // Every time the app comes forward, because the limit is enforced
            // when somebody opens it and this is the last moment it can be
            // brought up to date without anybody waiting for it.
            Task { await catchUp() }
        } else {
            checkpoint()
            // And on the way out, so the other phone learns about this session
            // before it is next opened rather than after. Both halves are local
            // file writes — iCloud carries them when it can — so this is not a
            // network call being started in front of a suspension.
            Task { await catchUp() }
        }
        syncCounting()
        // After the checkpoint, so that a day which has just been spent is
        // spent as far as the reminder is concerned too.
        mindTheAppointment()
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
            noteLocalChange()
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
            noteLocalChange()
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
        graceUsed = false
        graceEnds = nil
        notice = nil
        screen = .setup
        preferences.appointment.isOn = false
        ringer.silence()
        carried = nil
        ThePlace.forget()
        // Including the copy in iCloud, or the next phone to open would put it
        // straight back and "forget everything" would have meant "wait a week
        // and then get it back".
        Task { [cloud] in await cloud.forget() }
    }

    // MARK: - The other phones

    /// Whether the agreement follows this reader to their other devices.
    var carriesBetweenDevices: Bool { preferences.carriesBetweenDevices }

    /// Start or stop carrying it.
    ///
    /// Switching it on reconciles at once, so the phone that was behind catches
    /// up while somebody is still looking at the switch. Switching it off takes
    /// the copy down: a record left in iCloud after somebody said stop would be
    /// a record they had no way to reach.
    func carryBetweenDevices(_ on: Bool) {
        guard on != preferences.carriesBetweenDevices else { return }
        preferences.carriesBetweenDevices = on
        if on {
            Task { await catchUp() }
        } else {
            Task { [cloud] in await cloud.forget() }
        }
    }

    /// Pull down what the reader's other phones have said, reconcile it with
    /// what this one knows, and put the answer back.
    ///
    /// Best effort in every direction. No iCloud account, no signal, iCloud
    /// having a bad afternoon — all of them come back as "nothing up there",
    /// and the app carries on exactly as it did before this feature existed.
    /// Nothing here is allowed to block anybody from opening Instagram, and
    /// nothing here is allowed to fail loudly: a limit that stops working when
    /// the network does is not a limit.
    ///
    /// Every question about what happens when the two copies disagree is
    /// answered by `Carried.merge`, which is pure and has its own tests. This
    /// function only decides *when* to ask and what to do with the answer.
    func catchUp() async {
        guard preferences.carriesBetweenDevices, hasSomethingToRemember else { return }

        var ours = Carried(
            version: carried?.version ?? 0,
            limit: limit,
            day: ledger.day,
            byDevice: carried?.day == ledger.day ? (carried?.byDevice ?? [:]) : [:]
        )
        ours.byDevice[phone] = spentHere

        let theirs = await cloud.fetch()
        let merged = theirs.map { Carried.merge(ours, $0) } ?? ours
        adopt(merged)
        // Only when it would change what is up there. A write that says what
        // the record already says is a sync for nobody.
        if merged != theirs {
            await cloud.put(merged)
        }
    }

    /// What the other phones had spent today, as of the last reconciliation.
    private var elsewhere: TimeInterval {
        guard let carried, carried.day == ledger.day else { return 0 }
        return carried.byDevice
            .filter { $0.key != phone }
            .values
            .reduce(0, +)
    }

    /// What this phone alone has spent today.
    ///
    /// The ledger holds the whole day's total, wherever it was spent, because
    /// that is the number every rule in the app is written against. This phone's
    /// own share is the part of it that did not come from anywhere else — which
    /// is the only figure it has any business writing down.
    private var spentHere: TimeInterval {
        max(0, ledger.seconds - elsewhere)
    }

    /// Take a reconciled agreement as the truth.
    private func adopt(_ merged: Carried) {
        carried = merged
        store.save(merged, for: .carried)

        let total = merged.byDevice.values.reduce(0, +)
        if merged.day == ledger.day {
            if total != ledger.seconds {
                ledger = UsageLedger(day: ledger.day, seconds: total, endsAt: ledger.endsAt)
            }
        } else if merged.day > ledger.day, ledger.hasEnded(by: clock.now) {
            ledger = UsageLedger(
                day: merged.day,
                seconds: total,
                endsAt: merged.day.end(calendar: calendar)
            )
            announced.removeAll()
        }
        // The remaining case is two phones in two time zones, one of them
        // already into tomorrow while this one's day has not ended. Only the
        // agreement crosses over; the figures do not, because a day that has
        // not ended here cannot be ended by a phone somewhere else. See
        // `UsageLedger.hasEnded`, which is the same rule a single phone follows
        // when it travels.

        if merged.limit != limit {
            limit = merged.limit
        }
        persist()
        evaluateScreen()
        syncCounting()
        mindTheAppointment()
    }

    /// Say that something on this phone has changed, so the other phones can
    /// tell which copy came later.
    ///
    /// A counter rather than a timestamp, and deliberately: the app already
    /// refuses to trust this phone's clock about anything that matters, and it
    /// would be a strange place to start.
    private func noteLocalChange() {
        let noted = Carried(
            version: (carried?.version ?? 0) + 1,
            limit: limit,
            day: ledger.day,
            byDevice: carried?.day == ledger.day ? (carried?.byDevice ?? [:]) : [:]
        )
        carried = noted
        store.save(noted, for: .carried)
        guard preferences.carriesBetweenDevices else { return }
        Task { await catchUp() }
    }

    // MARK: - The appointment

    /// The daily reminder, as it stands.
    var appointment: Appointment { preferences.appointment }

    /// Switch the reminder on, at the hour already chosen.
    ///
    /// Asks the phone first, and stays off if the phone says no. A switch that
    /// slides across while nothing was actually granted is worse than no switch
    /// at all: it promises a reminder that will never arrive, which is exactly
    /// the failure this feature exists to avoid.
    @discardableResult
    func turnOnAppointment() async -> Bool {
        guard await ringer.ask() else { return false }
        preferences.appointment.isOn = true
        mindTheAppointment()
        return true
    }

    func turnOffAppointment() {
        preferences.appointment.isOn = false
        mindTheAppointment()
    }

    /// Move it to another hour. Free, in both directions, at any time.
    ///
    /// Nothing about when a reminder rings changes how much time there is, so
    /// none of the waiting rules apply. This is the one setting in Quiet that
    /// is purely about the shape of your day rather than about the promise.
    func moveAppointment(to minutesAfterMidnight: Int) {
        let wrapped = ((minutesAfterMidnight % 1440) + 1440) % 1440
        guard wrapped != preferences.appointment.minutesAfterMidnight else { return }
        preferences.appointment.minutesAfterMidnight = wrapped
        mindTheAppointment()
    }

    /// Whether Instagram has been on screen today.
    ///
    /// Read off the ledger rather than kept separately, because the ledger is
    /// already the app's answer to "how much of today has been spent" and a
    /// second record of the same fact is a second fact. A day whose ledger has
    /// rolled has nothing spent in it yet, which is the honest answer at four
    /// in the morning.
    private var hasOpenedToday: Bool {
        ledger.day == today && ledger.seconds > 0
    }

    /// Put the coming week's reminders on the phone, or take them off.
    ///
    /// Recomputed from scratch every time rather than adjusted, so there is one
    /// answer to what is pending and it is this function's. Nothing before
    /// setup and nothing after being forgotten: an app that has never been used
    /// has no window to remind anybody about.
    private func mindTheAppointment() {
        guard hasSomethingToRemember else {
            ringer.silence()
            return
        }
        ringer.ring(at: preferences.appointment.rings(
            after: clock.now,
            openedToday: hasOpenedToday,
            calendar: calendar
        ))
    }

    // MARK: - Somebody mid-sentence

    /// Whether a message is being typed on the page right now.
    private var isTyping = false

    /// When the courtesy runs out, on the uptime clock. `nil` when none is
    /// running.
    private var graceEnds: TimeInterval?

    /// Once a day. Spent whether or not it was needed for long.
    private var graceUsed = false

    /// How long the day may run over so that a sentence can be finished.
    ///
    /// Twenty seconds, and the number matters less than the shape: this is not
    /// extra time on Instagram, it is the end of one sentence. Long enough to
    /// finish what your thumbs were already doing, far too short to be worth
    /// opening a keyboard for.
    static let courtesy: TimeInterval = 20

    /// The page saying somebody is typing, or has stopped.
    ///
    /// Stopping ends the courtesy immediately rather than letting it run out:
    /// the sentence is finished, and the point of it was the sentence.
    func setTyping(_ on: Bool) {
        guard isTyping != on else { return }
        isTyping = on
        if !on { graceEnds = nil }
        evaluateScreen()
        syncCounting()
    }

    /// Whether the curtain is being held for a moment.
    ///
    /// The time still counts. Nothing here is given away — the day simply ends
    /// twenty seconds over, on the ledger as much as on the screen — which is
    /// what makes this a courtesy rather than a hole. The one door it could
    /// have opened is shut by the cap and by `graceUsed`: it cannot be had
    /// twice, and it cannot be extended by typing faster.
    private var isFinishingASentence: Bool {
        guard let graceEnds else { return false }
        return uptime() < graceEnds
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
        graceUsed = false
        graceEnds = nil
        persist()
    }

    private func evaluateScreen() {
        // Guarded on whether setup has happened, not on which screen is
        // showing. Guarding on the screen looked equivalent and was not: at
        // launch the screen still holds its initial `.setup` value, so this
        // returned early every time and a returning user was shown the
        // onboarding question forever.
        guard setupDay != nil else { return }

        // The day has run out while somebody is mid-sentence. Once, for twenty
        // seconds, the curtain waits — see `courtesy`.
        if ledger.isSpent(limitMinutes: limit.minutes), isTyping, !graceUsed, graceEnds == nil {
            graceUsed = true
            graceEnds = uptime() + Self.courtesy
        }

        let spent = ledger.isSpent(limitMinutes: limit.minutes) && !isFinishingASentence
        let target: Screen = spent ? .spent : .browsing
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
