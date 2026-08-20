import Observation
import SwiftUI
import UIKit
import WebKit

/// Somebody the search found. A name and nothing else: no follower count to
/// measure yourself against, no picture to load, no "suggested for you".
struct Person: Identifiable, Decodable, Equatable, Sendable {
    let username: String
    let name: String

    var id: String { username }
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

    /// False until the first page has finished, or failed. While it is false the
    /// browsing screen keeps Quiet's own paper over the top, so a cold launch
    /// shows a considered blank rather than the white rectangle of a web view
    /// that has not painted yet.
    private(set) var hasLoaded = false

    func open(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func goHome() {
        open(ContentRules.home)
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
            self?.goHome()
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
        for (const path of paths) {
          try {
            const response = await fetch(path, {
              credentials: "same-origin",
              headers: { "X-IG-App-ID": appID }
            });
            if (!response.ok) { continue; }
            const data = await response.json();
            const found = (data && data.users) || [];
            return JSON.stringify(found.slice(0, 6).map(function (entry) {
              const user = entry.user || {};
              return { username: user.username || "", name: user.full_name || "" };
            }).filter(function (person) { return person.username.length > 0; }));
          } catch (error) {
            // Try the next shape of the same request, then give up quietly.
          }
        }
        return null;
        """

        let answer = try? await webView.callAsyncJavaScript(
            body,
            arguments: ["query": trimmed, "appID": Self.appID],
            in: nil,
            contentWorld: .defaultClient
        )
        guard let json = answer as? String, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Person].self, from: data)
    }

    /// The identifier Instagram's own web client sends. Without it the newer
    /// endpoint answers 403 and no explanation.
    private static let appID = "936619743392459"

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
        webView.scrollView.contentInset = inset
        webView.scrollView.verticalScrollIndicatorInsets = inset
        webView.load(URLRequest(url: ContentRules.home))

        surface.adopt(webView, missing: payload.missing)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.scrollView.contentInset != inset {
            webView.scrollView.contentInset = inset
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
