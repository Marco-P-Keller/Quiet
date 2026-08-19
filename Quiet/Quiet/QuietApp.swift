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

    init() {
        let store = KeychainStore()
        let clock = MonotonicClock(store: store)
        #if DEBUG
        // Nothing unless a launch argument asks for it, and none of it exists
        // in a build anybody can install.
        Rehearsal.prepare(store: store, clock: clock)
        #endif
        _session = State(initialValue: QuietSession(store: store, clock: clock))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
    }
}
