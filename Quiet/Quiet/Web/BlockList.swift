import Foundation
import WebKit

/// The same refusals, enforced by WebKit rather than by Quiet.
///
/// Everything else in the app is a decision the app makes. The navigation
/// delegate cancels a page it does not like; `trim.js` refuses a tap before the
/// client sees it. Both are code of Quiet's, running inside a process where
/// Instagram's own code also runs, and both can only refuse what they are
/// shown.
///
/// A content rule list is not that. It is compiled once and handed to WebKit,
/// which applies it to every load in the view before anything of Quiet's is
/// consulted — including the loads nothing of Quiet's ever sees:
///
///   * a frame inside a page, which the delegate is shown but which `trim.js`
///     cannot reach across;
///   * a `fetch` or `XMLHttpRequest` Instagram's client makes, which is not a
///     navigation at all and which no navigation delegate is ever asked about;
///   * the second and third hop of a redirect chain.
///
/// What it is **not** is a filter on what Instagram sends. The reels injected
/// into a feed arrive as ordinary feed data over an ordinary API address, and
/// no rule that could be written here would separate them from the posts around
/// them without also taking the posts. That is what `trim.js` is for, and it is
/// why the two layers both exist.
///
/// So: a second lock on the same doors, made of addresses, which is the one
/// material in this app that Instagram cannot change by renaming a class.
enum BlockList {
    /// The name WebKit files the compiled list under.
    ///
    /// Carries a version. A compiled list is cached on disk between launches,
    /// and a cache is exactly the thing that goes on serving last month's rules
    /// after somebody edits this file — so the identifier changes whenever the
    /// rules do, and the old one is thrown away.
    static let identifier = "quiet.block.1"

    /// Any host under Instagram's name, written the way a content rule list
    /// writes it. `url-filter` is matched against the whole address, so the
    /// scheme and the host have to be spelled out.
    private static let instagram = "^https?://([a-z0-9-]+\\.)*instagram\\.com"

    /// Every address the app refuses, as one alternation.
    ///
    /// Mirrors `ContentRules.blockedRoots`, and the mirroring is checked by a
    /// test rather than trusted — three copies of this table now exist, in
    /// Swift, in JavaScript and here, and the day they disagree the one that is
    /// wrong is silently the one that matters.
    private static let roots = "reels?|tv|explore|directory"

    /// The addresses this refuses, as regular expressions.
    static var filters: [String] {
        [
            // /reels/, /reel/…, /tv/…, /explore/…, /directory/…
            "\(instagram)/(\(roots))(/|$)",
            // /accounts/suggested/ — Explore wearing a different hat.
            "\(instagram)/accounts/suggested(/|$)",
            // /someone/reels/ — the reels tab on a profile.
            "\(instagram)/[^/]+/reels(/|$)",
        ]
    }

    /// The rules, as WebKit's own JSON.
    ///
    /// Only `document` and `raw`. Not images, not media, not stylesheets: a
    /// rule that blocked those would be one bad address away from a feed with
    /// holes in it, and the whole argument for this layer is that it cannot be
    /// wrong in a way anybody has to debug from a photograph.
    static var rules: String {
        let list: [[String: Any]] = filters.map { filter in
            [
                "trigger": [
                    "url-filter": filter,
                    "resource-type": ["document", "raw"],
                ],
                "action": ["type": "block"],
            ]
        }
        // Serialised rather than written out, and the difference is not
        // tidiness. Every filter above contains `\.`, which is how a regular
        // expression spells a full stop and is *not* a legal escape in JSON —
        // so the hand-built version produced a document nothing could parse.
        // WebKit would have refused it on a real phone exactly as it refused it
        // here, the app would have run on one layer instead of two, and the
        // only thing that would ever have said so is a line in the panel.
        guard let data = try? JSONSerialization.data(withJSONObject: list),
              let text = String(data: data, encoding: .utf8) else {
            // Unreachable for a list of strings, and empty rather than `[]` on
            // purpose: an empty document fails to compile and is reported,
            // where `[]` would compile into a lock that holds nothing while
            // announcing success.
            return ""
        }
        return text
    }

    /// Compile the list and hand it to a configuration.
    ///
    /// Asynchronous because compiling is, and because the alternative — blocking
    /// the launch on it — would trade a lock that arrives a moment late for an
    /// app that opens a moment late. The first page is refused by the delegate
    /// either way; this is the second lock, and a second lock that clicks
    /// shut half a second after the first is still a second lock.
    ///
    /// A failure is reported rather than swallowed. It means the app is running
    /// on one layer instead of two, which is not a crisis and is not nothing.
    /// `store` is `nil` rather than `.default()` for the reason two other
    /// initialisers in this project now carry a paragraph about: a default
    /// argument is evaluated at the call site, and that store belongs to the
    /// main actor. Resolved in the body, which is isolated.
    @MainActor
    static func install(
        into configuration: WKWebViewConfiguration,
        store: WKContentRuleListStore? = nil,
        then report: @escaping @MainActor (Error?) -> Void = { _ in }
    ) {
        // Annotated, because `default()` is an implicitly unwrapped optional
        // and `??` would otherwise flatten the whole thing to something there
        // is nothing left to bind.
        let resolved: WKContentRuleListStore? = store ?? WKContentRuleListStore.default()
        guard let resolved else {
            report(Failure.noStore)
            return
        }
        resolved.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: rules
        ) { list, error in
            // WebKit answers on the main thread. Said out loud rather than
            // hopped to, the way `ScriptRelay` does it a file away: a `Task`
            // here would carry a configuration that is not `Sendable` across a
            // boundary it never actually crosses.
            MainActor.assumeIsolated {
                if let list {
                    configuration.userContentController.add(list)
                    report(nil)
                } else {
                    report(error ?? Failure.noStore)
                }
            }
        }
    }

    enum Failure: Error {
        /// WebKit has no rule list store, which happens on no phone and is
        /// still not a thing to force-unwrap.
        case noStore
    }
}
