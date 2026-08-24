#if DEBUG
import Foundation

/// Puts the app into a state it would otherwise take a day of use to reach, so
/// that somebody — or a machine — can look at it.
///
/// This exists because of one screen. The curtain is the moment the whole app
/// turns on, and reaching it honestly costs the shortest limit the app allows:
/// five minutes of staring at a simulator. Everything else follows from having
/// that door: the panel, the limit screen, the same screens at the largest text
/// size, the same screens in another language.
///
/// It is wrapped in `#if DEBUG` in its entirety, so none of it exists in a
/// build anybody can install. It writes the same values the app writes for
/// itself, through the same store, and then gets out of the way — it has no
/// opinion about the app's behaviour, which is the only way a rehearsal is
/// worth trusting.
///
///     xcrun simctl launch booted com.connexa.quiet -QuietRehearsal spent
enum Rehearsal {
    /// The launch argument, followed by the name of a scene.
    static let flag = "-QuietRehearsal"

    enum Scene: String {
        /// An empty install: the question the app opens with.
        case fresh
        /// Set up some days ago, nothing spent yet.
        case browsing
        /// Today is gone.
        case spent
        /// Browsing, with the panel open.
        case panel
        /// Browsing, with the limit screen open.
        case limit
        /// Browsing, with the search screen open.
        case search
        /// The second and a half the app opens with, held still so that it can
        /// be photographed. It is the one screen in Quiet that is gone before
        /// anybody could take a picture of it.
        case opening
    }

    /// Skip the opening, without asking for a scene.
    ///
    /// For the one UI test that drives the app from an empty install. A machine
    /// has no eyes to read a sentence with, and a screen it cannot see is a
    /// second and a half in which its first tap goes nowhere.
    static let noOpening = "-QuietNoOpening"

    static var skipsOpening: Bool {
        if ProcessInfo.processInfo.arguments.contains(noOpening) { return true }
        guard let scene else { return false }
        return scene != .opening
    }

    static var holdsOpening: Bool { scene == .opening }

    /// The scene named on the command line, if there is one.
    static var scene: Scene? {
        scene(in: ProcessInfo.processInfo.arguments)
    }

    static func scene(in arguments: [String]) -> Scene? {
        guard let flagIndex = arguments.firstIndex(of: flag),
              arguments.index(after: flagIndex) < arguments.endIndex else { return nil }
        return Scene(rawValue: arguments[arguments.index(after: flagIndex)])
    }

    /// Write the state the scene needs, before the session reads anything.
    ///
    /// Always clears first. The store outlives the app on purpose, so a scene
    /// that only wrote what it cared about would inherit whatever the previous
    /// launch left behind, and no two runs would photograph the same app.
    static func prepare(
        store: any StateStore,
        clock: MonotonicClock,
        calendar: Calendar = .current,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        guard let scene = scene(in: arguments) else { return }

        StoreKey.allCases.forEach(store.remove)
        // The glyphs the row was drawn with last time, and how long the app has
        // been on screen. Both live outside the store, and both change what a
        // photograph shows: a remembered house instead of Quiet's fallback, or
        // the App Store's own five-star sheet arriving over the screen being
        // photographed.
        Remembered.forget()
        Applause.forget()
        guard scene != .fresh else { return }

        let today = DayKey(clock.now, calendar: calendar)
        // A week ago, so the app is past teaching the gesture and the hint is
        // not sitting over the screen being photographed.
        store.save(DayKey(ordinal: today.ordinal - 7), for: .setupDay)
        store.save(LimitState(minutes: 20), for: .limit)
        store.save(
            UsageLedger(day: today, seconds: scene == .spent ? 20 * 60 : 0),
            for: .usage
        )
    }

    /// The scenes that are places in the app rather than states of the day.
    @MainActor
    static func open(_ session: QuietSession) {
        switch scene {
        case .panel, .limit: session.isPanelShowing = true
        case .search: session.isSearchShowing = true
        default: break
        }
    }

    static var opensLimit: Bool { scene == .limit }
}
#endif
