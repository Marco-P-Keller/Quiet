import Foundation
import WebKit

/// Where you were, kept for twenty minutes.
///
/// The app opens at the top of the feed every time, and not because anybody
/// chose that: iOS discards a web view under memory pressure, and what comes
/// back is a fresh page. So you scroll the same eight posts again. It is the
/// smallest thing in the app and it is felt on every single launch.
///
/// `interactionState` is WebKit's own answer — the page, its history and the
/// scroll position in one opaque value, restored without a load, which is why
/// it comes back instantly rather than fetching the feed again.
///
/// **Twenty minutes, and then it is thrown away.** That is the whole of the
/// judgement here. Coming back to where you were is a courtesy while you are
/// still in the middle of something; coming back to this morning's feed at
/// seven in the evening is not a courtesy, it is an app that has not noticed
/// the day moved on. Nothing is more annoying than a restore that restores the
/// wrong thing, so the window is deliberately short.
///
/// A preference, not a promise: it lives where preferences live, and losing it
/// costs a scroll rather than a rule.
enum ThePlace {
    private static let state = "quiet.place"
    private static let when = "quiet.place.at"
    private static let address = "quiet.place.address"

    /// How stale a place may be and still be somewhere you were.
    static let fresh: TimeInterval = 20 * 60

    /// Put the page away, if WebKit will hand it over in a form that can be
    /// written down.
    ///
    /// `interactionState` is typed as `Any?` and is documented as opaque.
    /// WebKit hands back `Data`, and this only ever stores that: an opaque
    /// value that has to be archived to be kept is a value that could change
    /// shape under a future WebKit, and the cost of guessing wrong is a crash
    /// on launch. Skipping is free — you get the feed from the top, which is
    /// exactly what happens today.
    @MainActor
    static func keep(
        _ webView: WKWebView,
        now: Date = Date(),
        in defaults: UserDefaults = .standard
    ) {
        guard let data = webView.interactionState as? Data else { return }
        defaults.set(data, forKey: state)
        defaults.set(now.timeIntervalSince1970, forKey: when)
        defaults.set(webView.url?.absoluteString ?? "", forKey: address)
    }

    /// Put the page back, and say whether it happened.
    ///
    /// Refused on anything Quiet does not show. A restored state does not go
    /// through the navigation delegate — that is the point of it — so the URL
    /// rules never see it, and without this check a state saved on a page the
    /// app now refuses would walk straight back in through the side door.
    @MainActor
    @discardableResult
    static func restore(
        into webView: WKWebView,
        now: Date = Date(),
        in defaults: UserDefaults = .standard
    ) -> Bool {
        guard let data = defaults.data(forKey: state) else { return false }
        guard isFresh(defaults.double(forKey: when), now: now),
              isStillShown(defaults.string(forKey: address)) else {
            forget(in: defaults)
            return false
        }
        webView.interactionState = data
        return true
    }

    /// Whether a place is recent enough to be somewhere you were.
    ///
    /// Pure, because it is the judgement rather than the plumbing: twenty
    /// minutes is the difference between a courtesy and an app that has not
    /// noticed the day moved on.
    static func isFresh(_ saved: TimeInterval, now: Date) -> Bool {
        guard saved > 0 else { return false }
        let age = now.timeIntervalSince1970 - saved
        // A place from the future is a clock that moved, not a place.
        return age >= 0 && age <= fresh
    }

    /// Whether the app would still open that address today.
    ///
    /// A restored state does not go through the navigation delegate — that is
    /// the point of it — so the URL rules never see it. Without this, a state
    /// saved on a page the app refuses would walk back in through the side
    /// door. Nothing written down is trusted more than the rules.
    static func isStillShown(_ address: String?) -> Bool {
        guard let address, !address.isEmpty else { return true }
        guard let url = URL(string: address) else { return false }
        return ContentRules.routing(for: url) == .allow
    }

    static func forget(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: state)
        defaults.removeObject(forKey: when)
        defaults.removeObject(forKey: address)
    }
}
