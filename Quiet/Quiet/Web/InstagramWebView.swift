import Observation
import SwiftUI
import UIKit
import WebKit

/// Somebody the search found: a name, a name, and a face.
///
/// No follower count — that is a number to measure yourself against and it has
/// no business in a list of people you already know. The picture is here
/// because a row of names is a spreadsheet, and finding a friend is something
/// you do by recognising them.
struct Person: Identifiable, Decodable, Equatable, Sendable {
    let username: String
    let name: String
    /// The profile picture, base64, fetched by the page. Empty when the image
    /// could not be had — a monogram stands in, rather than a hole.
    var picture: String?

    var id: String { username }

    var image: UIImage? {
        guard let picture, let data = Data(base64Encoded: picture) else { return nil }
        return UIImage(data: data)
    }
}

/// A handle on the live web view, so the rest of the app can send it somewhere
/// without owning it.
@MainActor
@Observable
final class WebSurface {
    @ObservationIgnored fileprivate weak var webView: WKWebView?

    /// Resources that failed to load out of the bundle. Surfaced in the UI
    /// rather than swallowed.
    private(set) var missingResources: [String] = []

    /// Whether Quiet's row has drawn itself in, because somebody is reading.
    ///
    /// It never leaves — a control that disappears is a control you hunt for —
    /// but while the page is moving away under your thumb there is no reason
    /// for it to be at full size.
    private(set) var isBarCollapsed = false

    /// The signed-in username, read out of Instagram's own navigation before
    /// that row is taken out. `nil` until a page carrying it has loaded, which
    /// is why the profile entry in Quiet's row appears a moment after the rest.
    private(set) var me: String?

    /// Your own face, for the last entry in the row — because Instagram's ends
    /// in a photograph rather than an outline of a person.
    private(set) var myFace: UIImage?

    /// False until the first page has finished, or failed. While it is false the
    /// browsing screen keeps Quiet's own paper over the top, so a cold launch
    /// shows a considered blank rather than the white rectangle of a web view
    /// that has not painted yet.
    private(set) var hasLoaded = false

    func open(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    /// What a tap on the status bar has always done.
    func scrollToTop() {
        guard let scrollView = webView?.scrollView else { return }
        scrollView.setContentOffset(
            CGPoint(x: 0, y: -scrollView.adjustedContentInset.top),
            animated: true
        )
    }

    /// Forget the Instagram session entirely: cookies, storage, caches. Quiet
    /// never held the password, so this is the whole of what there is to forget.
    func signOut(completion: @escaping () -> Void = {}) {
        let store = WKWebsiteDataStore.default()
        store.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            self?.open(ContentRules.home)
            completion()
        }
    }

    /// Who matches this name.
    ///
    /// The request is made by Instagram's own page, with the page's own cookies,
    /// so it is the same search the site would run — and Quiet still makes no
    /// request of its own, which is a sentence on the About screen that has to
    /// stay true.
    ///
    /// Only people come back. No hashtags, no places, no posts, no grid of
    /// strangers: the objection to a search *page* was never the searching, it
    /// was everything such a page carries along with it.
    ///
    /// `nil` means the question could not be asked — offline, signed out, or
    /// Instagram moved the endpoint — which is a different thing from nobody
    /// being called that, and the panel says the two differently.
    func people(matching query: String) async -> [Person]? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let webView else { return nil }

        let body = """
        const term = encodeURIComponent(query);
        const paths = [
          "/api/v1/web/search/topsearch/?context=blended&query=" + term,
          "/web/search/topsearch/?context=blended&query=" + term
        ];

        // The face, fetched by the page from the same place the page would
        // fetch it, and handed over as bytes. Quiet still asks nobody for
        // anything. A picture that will not come is not an error worth
        // reporting — the list stands in a letter instead.
        async function face(url) {
          if (!url) { return ""; }
          try {
            const response = await fetch(url, { credentials: "omit" });
            if (!response.ok) { return ""; }
            const buffer = await response.arrayBuffer();
            if (buffer.byteLength > 300000) { return ""; }
            const bytes = new Uint8Array(buffer);
            let binary = "";
            for (let i = 0; i < bytes.length; i++) {
              binary += String.fromCharCode(bytes[i]);
            }
            return btoa(binary);
          } catch (error) {
            return "";
          }
        }

        for (const path of paths) {
          try {
            const response = await fetch(path, {
              credentials: "same-origin",
              headers: { "X-IG-App-ID": appID }
            });
            if (!response.ok) { continue; }
            const data = await response.json();
            const found = (data && data.users) || [];
            const people = found.slice(0, 6)
              .map(function (entry) { return entry.user || {}; })
              .filter(function (user) { return (user.username || "").length > 0; });
            // All six at once. One after another is six round trips of
            // waiting for a list somebody is watching appear.
            const faces = await Promise.all(people.map(function (user) {
              return face(user.profile_pic_url);
            }));
            return JSON.stringify(people.map(function (user, index) {
              return {
                username: user.username,
                name: user.full_name || "",
                picture: faces[index]
              };
            }));
          } catch (error) {
            // Try the next shape of the same request, then give up quietly.
          }
        }
        return null;
        """

        let answer = try? await webView.callAsyncJavaScript(
            body,
            arguments: ["query": trimmed, "appID": WebScripts.appID],
            in: nil,
            contentWorld: .defaultClient
        )
        guard let json = answer as? String, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Person].self, from: data)
    }

    fileprivate func adopt(_ webView: WKWebView, missing: [String]) {
        self.webView = webView
        missingResources = missing
        hasLoaded = false
    }

    /// Called when the first navigation settles, whether it worked or not. A
    /// failed load must lift the cover too, or a person offline would be left
    /// looking at an empty page with no explanation.
    fileprivate func markLoaded() {
        hasLoaded = true
    }

    fileprivate func setBar(collapsed: Bool) {
        guard collapsed != isBarCollapsed else { return }
        isBarCollapsed = collapsed
    }

    fileprivate func note(me name: String, picture: String?) {
        if me != name { me = name }
        guard let picture, let data = Data(base64Encoded: picture) else { return }
        myFace = UIImage(data: data)
    }

    /// Where Quiet's own row can send you.
    func goToFeed() { open(ContentRules.feed) }
    func goToMessages() { open(ContentRules.messages) }

    func goToMyProfile() {
        guard let me, let url = ContentRules.profile(forHandle: me) else { return }
        open(url)
    }
}

/// Instagram, minus the parts that were built to keep you there.
struct InstagramWebView: UIViewRepresentable {
    let surface: WebSurface
    let session: QuietSession
    /// How much of the top and bottom of the screen belongs to somebody else —
    /// the status bar above, Quiet's own row of controls below.
    var inset: UIEdgeInsets

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, surface: surface)
    }

    func makeUIView(context: Context) -> WKWebView {
        let payload = WebScripts.load()

        let controller = WKUserContentController()
        payload.scripts.forEach(controller.addUserScript)
        controller.add(ScriptRelay(context.coordinator), name: WebScripts.messageHandler)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        // Persistent, so logging in is something you do once.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        // Nothing plays until someone asks it to. Autoplay is the smallest of
        // the hooks and among the easiest to remove.
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = UserAgent.mobileSafari(systemVersion: UIDevice.current.systemVersion)
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        // The page is given the whole screen and told which parts of it are
        // spoken for, rather than being given a smaller screen.
        //
        // This is the third attempt at the same half-inch of glass. Instagram
        // lays its header against the top of whatever it is given, so it ended
        // up under the clock. Making the web view shorter fixed that and
        // detached the site's own header into the middle of the feed, because a
        // sticky position is laid out against a viewport. Asking the page to
        // respect the safe area, with viewport-fit, did nothing at all — the
        // site's stylesheet does not consult it.
        //
        // A content inset changes neither the viewport nor the frame. WebKit
        // positions fixed elements against the unobscured rect, which is what
        // this defines, and it is the same mechanism a browser uses for its own
        // toolbars.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // Only the top. The pill floats *over* the page, the way Instagram's
        // own does — insetting the bottom as well left a band of black beneath
        // it where the page had simply been told to stop.
        webView.scrollView.contentInset = UIEdgeInsets(top: inset.top, left: 0, bottom: 0, right: 0)
        webView.scrollView.verticalScrollIndicatorInsets = inset
        webView.load(URLRequest(url: ContentRules.home))

        context.coordinator.watch(webView.scrollView)
        surface.adopt(webView, missing: payload.missing)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let top = UIEdgeInsets(top: inset.top, left: 0, bottom: 0, right: 0)
        if webView.scrollView.contentInset != top {
            webView.scrollView.contentInset = top
            webView.scrollView.verticalScrollIndicatorInsets = inset
        }
        context.coordinator.session = session
    }

    @MainActor
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: WebScripts.messageHandler)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Watching the page move, so the row can get out of the way a little.
        ///
        /// Observed rather than delegated. WKWebView is its own scroll view's
        /// delegate and uses that seat for real work — scroll-to-top, zoom,
        /// keyboard avoidance — so taking it away to learn which way a thumb is
        /// going would be a poor trade.
        private var scrolling: NSKeyValueObservation?
        private var lastOffset: CGFloat = 0

        /// How far the page has to move before the row believes it. Small
        /// enough to feel immediate, large enough that a fingertip resting on
        /// the glass does not make it flicker.
        private static let meaningful: CGFloat = 8

        func watch(_ scrollView: UIScrollView) {
            lastOffset = scrollView.contentOffset.y
            scrolling = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.scrolled(view) }
            }
        }

        private func scrolled(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset.y
            let delta = offset - lastOffset
            guard abs(delta) > Self.meaningful else { return }
            lastOffset = offset

            // At the top of the page there is nothing to get out of the way of.
            let atTop = offset <= -scrollView.contentInset.top + 4
            surface.setBar(collapsed: atTop ? false : delta > 0)
        }

        var session: QuietSession
        let surface: WebSurface

        init(session: QuietSession, surface: WebSurface) {
            self.session = session
            self.surface = surface
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            // A nil target frame means a new window, which behaves as a main
            // frame for the purposes of every rule below.
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

            switch ContentRules.routing(for: url) {
            case .allow:
                decisionHandler(.allow)

            case let .refuse(surface):
                decisionHandler(.cancel)
                // Only speak up when a person did something. A refused subframe
                // is bookkeeping, not an answer to anyone.
                if isMainFrame {
                    session.report(surface)
                }

            case .openOutside:
                guard isMainFrame else {
                    // A third-party frame inside a page: an embed, a captcha.
                    // There is nothing to hand to Safari here.
                    decisionHandler(.allow)
                    return
                }
                decisionHandler(.cancel)
                UIApplication.shared.open(url)

            case .ignore:
                // A scheme belonging to some app on the phone. The page asked;
                // the person did not.
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Links that ask for a new window get the window they already have.
            if let url = navigationAction.request.url {
                switch ContentRules.routing(for: url) {
                case .allow:
                    webView.load(URLRequest(url: url))
                case let .refuse(surface):
                    session.report(surface)
                case .openOutside:
                    UIApplication.shared.open(url)
                case .ignore:
                    break
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            surface.markLoaded()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            let code = (error as NSError).code
            guard code != NSURLErrorCancelled else { return }
            surface.markLoaded()
            if code == NSURLErrorNotConnectedToInternet || code == NSURLErrorNetworkConnectionLost {
                session.show(String(localized: "No connection."))
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            surface.markLoaded()
        }

        fileprivate func receive(_ message: WKScriptMessage) {
            // Only the page a person is looking at may say anything. The script
            // runs in every frame so that an embedded player never gets to
            // appear first, which means an advert's frame can post too.
            guard message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any],
                  let kind = body["kind"] as? String else { return }

            switch kind {
            case "refused":
                guard let name = body["surface"] as? String,
                      let surface = BlockedSurface(rawValue: name) else { return }
                session.report(surface)

            case "settings":
                // Quiet's mark, tapped beside Instagram's own settings.
                session.isPanelShowing = true

            case "search":
                // The magnifying glass, tapped in Quiet's own row.
                session.isSearchShowing = true

            case "me":
                // Read out of Instagram's navigation before it was taken out.
                if let name = body["username"] as? String {
                    surface.note(me: name, picture: body["picture"] as? String)
                }

            default:
                break
            }
        }
    }
}

/// Holds the coordinator weakly, because `WKUserContentController` holds its
/// message handlers strongly and the coordinator owns the web view's lifetime.
private final class ScriptRelay: NSObject, WKScriptMessageHandler {
    private weak var coordinator: InstagramWebView.Coordinator?

    init(_ coordinator: InstagramWebView.Coordinator) {
        self.coordinator = coordinator
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated {
            coordinator?.receive(message)
        }
    }
}

/// Instagram serves a stripped-down page to anything it does not recognise as a
/// browser. Quiet is a browser, showing the site as Safari would, so it says so.
enum UserAgent {
    static func mobileSafari(systemVersion: String) -> String {
        let underscored = systemVersion.replacingOccurrences(of: ".", with: "_")
        let major = systemVersion.split(separator: ".").first.map(String.init) ?? "17"
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(underscored) like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(major).0 "
            + "Mobile/15E148 Safari/604.1"
    }
}
