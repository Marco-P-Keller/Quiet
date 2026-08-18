import Observation
import SwiftUI
import UIKit
import WebKit

/// A handle on the live web view, so the rest of the app can send it somewhere
/// without owning it.
@MainActor
@Observable
final class WebSurface {
    @ObservationIgnored fileprivate weak var webView: WKWebView?

    /// Resources that failed to load out of the bundle. Surfaced in the UI
    /// rather than swallowed.
    private(set) var missingResources: [String] = []

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

    fileprivate func adopt(_ webView: WKWebView, missing: [String]) {
        self.webView = webView
        missingResources = missing
    }
}

/// Instagram, minus the parts that were built to keep you there.
struct InstagramWebView: UIViewRepresentable {
    let surface: WebSurface
    let session: QuietSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
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
        webView.load(URLRequest(url: ContentRules.home))

        surface.adopt(webView, missing: payload.missing)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
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

        init(session: QuietSession) {
            self.session = session
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
                }
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            let code = (error as NSError).code
            guard code != NSURLErrorCancelled else { return }
            if code == NSURLErrorNotConnectedToInternet || code == NSURLErrorNetworkConnectionLost {
                session.show("No connection.")
            }
        }

        fileprivate func receive(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  body["kind"] as? String == "refused",
                  let name = body["surface"] as? String,
                  let surface = BlockedSurface(rawValue: name) else { return }
            session.report(surface)
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
