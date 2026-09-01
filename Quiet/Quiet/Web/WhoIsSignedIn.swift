import Foundation
import WebKit

/// What a new reading of Instagram's own account cookie means.
///
/// Pulled out of the watcher below and given no dependencies, because the one
/// case that matters is the one that is hardest to reach by hand: two accounts,
/// a switch between them, and a cookie that is briefly neither.
enum AccountChange: Equatable {
    /// The same account as before, or still nobody.
    case nothing
    /// Nobody, and now somebody. A sign-in.
    case signedIn
    /// Somebody, and now somebody else. The one this exists for.
    case switched
    /// Somebody, and now nobody. A sign-out, or a session that expired.
    case signedOut

    static func of(was: String?, now: String?) -> AccountChange {
        switch (was, now) {
        case let (was?, now?): return was == now ? .nothing : .switched
        case (nil, .some): return .signedIn
        case (.some, nil): return .signedOut
        case (nil, nil): return .nothing
        }
    }

    /// Whether a reading is one to act on.
    ///
    /// Two rules, and both of them are the kind that look like a detail and
    /// are the whole thing.
    ///
    /// The first reading is never acted on. At launch the app has just started
    /// and whoever is signed in has not changed; reading "nobody has looked
    /// yet" as "nobody is signed in" would call every launch a sign-in and
    /// every launch after one a switch, and the app would tear its own panes
    /// down on the way up.
    ///
    /// And only a switch is acted on. A sign-in is Instagram's own login flow,
    /// which navigates on its own and does not want a restart landing in the
    /// middle of it. A sign-out already has a path of its own through
    /// `WebSurface.signOut`, which tears the panes down itself — acting here
    /// too would tear them down twice, a second apart, in front of somebody.
    static func acts(on change: AccountChange, hasLooked: Bool) -> Bool {
        hasLooked && change == .switched
    }
}

/// Which Instagram account the web views are signed in to, watched.
///
/// Instagram lets somebody change accounts without ever passing through
/// Quiet's own sign-out: a sheet, two taps, and the same document belongs to
/// somebody else. **Nothing loads.** The two panes off the glass go on holding
/// the last person's feed and the last person's inbox, ready to be brought
/// forward by one tap, and the row goes on wearing their face.
///
/// The page cannot be asked. `trim.js` asks who it is once per document — and
/// an account switch is not a new document, so the answer it is holding is the
/// answer from before the switch. What *does* change, at the moment it happens,
/// is a cookie. `ds_user_id` is Instagram's own name for who this browser is,
/// it is set by the server rather than by anything on the page, and all three
/// panes share one cookie store, so one watcher covers the whole app.
///
/// It waits before answering. A switch is not one cookie write but a burst of
/// them, and somewhere in the middle of that burst there is a moment with no
/// account at all — answering there would read a sign-out followed by a
/// sign-in and restart the app twice.
@MainActor
final class WhoIsSignedIn: NSObject, WKHTTPCookieStoreObserver {
    /// Instagram's own name for which account this browser is.
    static let cookie = "ds_user_id"

    /// How long the cookies have to hold still. Long enough to cover the burst
    /// a switch arrives in, short enough that nobody has scrolled the old
    /// account's feed in the meantime.
    static let settle: TimeInterval = 1.2

    private let store: WKHTTPCookieStore

    /// Said without saying who. The new account's id is Instagram's identifier
    /// for a person, the app has no use for it beyond noticing that it changed,
    /// and a value that is never passed on is a value that cannot end up in a
    /// log.
    private let switched: () -> Void

    /// The last settled answer, and whether there has been one.
    ///
    /// Separate, rather than a double optional, because "nobody is signed in"
    /// and "nobody has looked yet" are different answers to the same question
    /// and reading the second as the first would restart the app at launch.
    private var known: String?
    private var hasLooked = false
    private var settling: Task<Void, Never>?

    init(
        store: WKHTTPCookieStore = WKWebsiteDataStore.default().httpCookieStore,
        switched: @escaping () -> Void
    ) {
        self.store = store
        self.switched = switched
        super.init()
        // Not removed anywhere. WebKit holds its observers weakly, and the
        // alternative — a `deinit` reaching for a store that is not `Sendable`
        // from a thread that is not the main actor — is a worse problem than
        // the one it solves.
        store.add(self)
        // The first reading is the baseline and never an event: the app has
        // just started and whoever is signed in has not changed.
        Task { await look() }
    }

    // Plain rather than `nonisolated`, the same way every WebKit delegate in
    // this app is written: the SDK's observer arrives on the main actor.
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        waitForItToSettle()
    }

    private func waitForItToSettle() {
        settling?.cancel()
        settling = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.settle))
            guard !Task.isCancelled else { return }
            await self?.look()
        }
    }

    /// Read the cookie, and say so if it is somebody else. What counts as
    /// somebody else, and when, is `AccountChange`.
    func look() async {
        let cookies = await store.allCookies()
        let now = cookies.first {
            $0.name == Self.cookie && $0.domain.hasSuffix("instagram.com")
        }?.value

        defer {
            known = now
            hasLooked = true
        }
        guard hasLooked else { return }
        let change = AccountChange.of(was: known, now: now)
        guard AccountChange.acts(on: change, hasLooked: hasLooked) else { return }
        switched()
    }
}
