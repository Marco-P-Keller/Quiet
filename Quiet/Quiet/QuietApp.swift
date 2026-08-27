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
        #if DEBUG
        // Nothing unless a launch argument asks for it, and none of it exists
        // in a build anybody can install.
        Rehearsal.prepare(store: store, clock: clock)
        #endif
        // After the rehearsal, and the order is load-bearing.
        //
        // Everything else here is read later: the session loads the store in
        // `start()`, long after this runs. Preferences are the one thing read
        // in an initialiser, so building them first means building them from
        // whatever was on the phone before the rehearsal wrote anything — and
        // a rehearsal that asks for the island then gets photographed wearing
        // the bar.
        //
        // It worked by accident until preferences moved up here: the view that
        // used to own them was built after this, which put it on the right side
        // of the rehearsal without anybody choosing that.
        let preferences = Preferences()
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
