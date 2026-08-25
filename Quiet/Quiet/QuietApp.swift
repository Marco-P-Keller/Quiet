import SwiftUI

/// Quiet.
///
/// Instagram, with the endless surfaces removed and a daily limit that cannot be
/// lifted in the moment it starts to bite.
///
/// The whole app is assembled here, in five lines, from parts that do not know
/// about each other: a store that outlives the app, a clock that will not go
/// backwards, and a session that spends the day.
@main
struct QuietApp: App {
    @State private var session: QuietSession

    /// How the app looks and what it says, as against what it promises.
    ///
    /// Built here rather than in the view that happens to need it first,
    /// because the session consults it too. It used to live in `RootView` and
    /// nowhere else, which was right for as long as only views cared.
    @State private var preferences: Preferences

    init() {
        let store = KeychainStore()
        let clock = MonotonicClock(store: store)
        let preferences = Preferences()
        #if DEBUG
        // Nothing unless a launch argument asks for it, and none of it exists
        // in a build anybody can install.
        Rehearsal.prepare(store: store, clock: clock)
        #endif
        _preferences = State(initialValue: preferences)
        _session = State(initialValue: QuietSession(
            store: store,
            clock: clock,
            preferences: preferences
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, preferences: preferences)
        }
    }
}
