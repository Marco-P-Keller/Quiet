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

    /// Bound to the panel's presentation. While the panel is up, the clock stops:
    /// time spent deciding how much time you want is not time on Instagram.
    var isPanelShowing = false {
        didSet { syncCounting() }
    }

    private let store: any StateStore
    private let clock: MonotonicClock
    private let calendar: Calendar

    private var isForeground = false
    private var ticker: Timer?
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
    private static let warnings = [5, 1]

    init(store: any StateStore, clock: MonotonicClock, calendar: Calendar = .current) {
        self.store = store
        self.clock = clock
        self.calendar = calendar
        ledger = UsageLedger(day: DayKey(clock.now, calendar: calendar))
    }

    // MARK: - Lifecycle

    /// Load what was saved and decide which screen to show. Safe to call twice.
    func start() {
        setupDay = store.load(DayKey.self, for: .setupDay)
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
        ledger = UsageLedger(day: today)
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
    var resetsAt: Date { today.end(calendar: calendar) }

    /// The first day the limit could be raised again, or `nil` if it could be
    /// raised now.
    var nextIncreaseDay: DayKey? { LimitPolicy.nextIncreaseDay(limit, today: today) }

    /// True when the device clock sits behind time the app has already seen.
    var isClockRewound: Bool { clock.isRewound }

    /// Whether the app should still point out the gesture that opens the panel.
    ///
    /// A hidden gesture explained exactly once, on the busiest screen of the
    /// first run, is a gesture most people will not have. Quiet repeats it on
    /// the first launch of each of the first three days and then stops, which
    /// costs no extra stored state: the day setup finished is already known.
    var isLearningTheGesture: Bool {
        guard let setupDay else { return false }
        return setupDay.days(to: today) < Self.teachingDays
    }

    private static let teachingDays = 3

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

    /// A rewound clock only threatens increases. Asking for less is always
    /// allowed, whatever the date says.
    private func guardRail(_ minutes: Int) -> LimitRefusal? {
        minutes > limit.minutes && isClockRewound ? .clockRewound : nil
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

    private var shouldCount: Bool {
        screen == .browsing && isForeground && !isPanelShowing
    }

    /// Start or stop the ticker to match `shouldCount`. Never reentrant: nothing
    /// it calls changes `screen`, `isForeground` or `isPanelShowing`.
    private func syncCounting() {
        if shouldCount {
            guard ticker == nil else { return }
            lastSample = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            // `.common` so the count keeps running while a finger is on a scroll
            // view — which is exactly when it matters.
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else {
            guard let timer = ticker else { return }
            ticker = nil
            timer.invalidate()
            accrue()
            lastSample = nil
            flush()
            clock.flush()
        }
    }

    private func tick() {
        accrue()
        if !ledger.isSpent(limitMinutes: limit.minutes) {
            announceIfNeeded()
        }
        evaluateScreen()
        syncCounting()
    }

    /// Fold elapsed foreground time into the ledger. Accounting only: it never
    /// changes which screen is showing.
    private func accrue() {
        let uptime = ProcessInfo.processInfo.systemUptime
        defer { lastSample = uptime }
        guard let previous = lastSample else { return }
        let elapsed = uptime - previous

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
        ledger.roll(to: day)
        limit = LimitPolicy.rolled(limit, to: day)
        announced.removeAll()
        persist()
    }

    private func evaluateScreen() {
        guard screen != .setup else { return }
        let target: Screen = ledger.isSpent(limitMinutes: limit.minutes) ? .spent : .browsing
        guard target != screen else { return }
        screen = target
        if target == .spent {
            notice = nil
            flush()
        }
    }

    private func announceIfNeeded() {
        let minutesLeft = Int(ceil(remaining / 60))
        guard let threshold = Self.warnings.first(where: { minutesLeft <= $0 }),
              !announced.contains(threshold) else { return }
        announced.insert(threshold)
        show(threshold == 1 ? "One minute left." : "\(threshold) minutes left.")
    }

    // MARK: - Persistence

    private func flush() {
        unsavedSeconds = 0
        store.save(ledger, for: .usage)
    }

    private func persist() {
        unsavedSeconds = 0
        store.save(limit, for: .limit)
        store.save(ledger, for: .usage)
    }

    /// Called when the app is about to lose the foreground, so nothing is lost if
    /// it is never resumed.
    func checkpoint() {
        accrue()
        flush()
        clock.flush()
    }
}
