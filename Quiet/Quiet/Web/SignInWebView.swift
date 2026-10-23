import Observation
import SwiftUI
import UIKit
import WebKit

/// Where somebody signs in to Instagram — and the one web view in the app that
/// carries nothing of Quiet's.
///
/// Every other page in the app runs `trim.css` and `trim.js`, and can talk back
/// to the app through `ScriptRelay`. This one has none of the three: an empty
/// `WKUserContentController`, no message handler, no block list, and the form
/// bar iOS draws over a field left where iOS put it. Instagram's sign-in page
/// is drawn the way Safari would draw it, and what is typed into it goes from
/// the keyboard to Instagram.
///
/// That is a claim, and it is in a file of its own so that it can be checked
/// rather than believed. Everything this view is built with is in
/// `configuration()`, and `SignInTests` fails the day a script arrives in it.
///
/// It shares the persistent store with the panes, which is the whole of how a
/// sign-in here becomes a session there. See `SignIn.isOver`.
struct SignInWebView: UIViewRepresentable {
    let start: URL
    let page: SignInPage
    let session: QuietSession
    let surface: WebSurface
    /// Instagram has answered with a page that is not part of signing in, and
    /// there is a session in the store.
    var onFinish: () -> Void

    /// What the view is made of, and all of it.
    ///
    /// The store is the panes' own — `.default()`, persistent — because a
    /// session nobody else can read is a sign-in that has to be done again on
    /// the other side. Nothing else is shared with them.
    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        configuration.websiteDataStore = .default()
        return configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(page: page, session: session, surface: surface, onFinish: onFinish)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.configuration())
        // The same name the panes give, so Instagram serves the same site.
        // A header on the request, not anything on the page. See `UserAgent`.
        webView.customUserAgent = UserAgent.mobileSafari(systemVersion: UIDevice.current.systemVersion)
        webView.allowsBackForwardNavigationGestures = true
        // The app's ground under a page that has not painted yet, rather than
        // WebKit's white. See the same lines in `WebPane.build`.
        webView.isOpaque = false
        webView.backgroundColor = Paper.groundColour
        webView.scrollView.backgroundColor = Paper.groundColour
        webView.underPageBackgroundColor = Paper.groundColour
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.watch(webView)
        webView.load(URLRequest(url: start))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopWatching()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        private let page: SignInPage
        private let session: QuietSession
        private let surface: WebSurface
        private let onFinish: () -> Void

        /// Said once. Instagram can answer the end of a sign-in with a redirect
        /// and a client-side move in the same breath, and two finishes would
        /// tear the panes down twice in front of somebody.
        private var finished = false

        private var watching: [NSKeyValueObservation] = []

        /// The view being watched, for the cookie store to ask about.
        private weak var webView: WKWebView?

        init(page: SignInPage, session: QuietSession, surface: WebSurface, onFinish: @escaping () -> Void) {
            self.page = page
            self.session = session
            self.surface = surface
            self.onFinish = onFinish
        }

        /// The address and the padlock, for the strip above the page.
        ///
        /// Observed rather than taken from the navigation delegate, because
        /// `url` also moves when Instagram's client changes the page without
        /// loading one — which is how the end of a sign-in can arrive, and the
        /// delegate hears nothing about it.
        ///
        /// And the cookies, because the two halves of `SignIn.isOver` need not
        /// arrive in order. Instagram can move the page first and set the
        /// session a moment later; asked only when the address moved, that
        /// sign-in was never over, and somebody was left on this screen holding
        /// Instagram's whole feed with none of Quiet on it.
        func watch(_ webView: WKWebView) {
            self.webView = webView
            webView.configuration.websiteDataStore.httpCookieStore.add(self)
            watching = [
                webView.observe(\.url, options: [.initial, .new]) { [weak self] view, _ in
                    MainActor.assumeIsolated { self?.moved(view) }
                },
                webView.observe(\.hasOnlySecureContent, options: [.initial, .new]) { [weak self] view, _ in
                    MainActor.assumeIsolated { self?.page.note(view) }
                },
            ]
        }

        func stopWatching() {
            watching.forEach { $0.invalidate() }
            watching = []
            webView?.configuration.websiteDataStore.httpCookieStore.remove(self)
            webView = nil
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard let webView else { return }
            askAgain(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            askAgain(webView)
        }

        /// Whether the page standing here now, with the cookies there are now,
        /// is the end of the sign-in.
        private func askAgain(_ webView: WKWebView) {
            guard !finished, let url = webView.url, !ContentRules.isSignInFlow(url) else { return }
            Task { await finishIfOver(at: url, in: webView) }
        }

        private func moved(_ webView: WKWebView) {
            page.note(webView)
            askAgain(webView)
        }

        private func finishIfOver(at url: URL, in webView: WKWebView) async -> Bool {
            guard !finished else { return true }
            let over = SignIn.isOver(at: url, hasSession: await hasSession(webView))
            if over, !finished {
                finished = true
                onFinish()
            }
            return over
        }

        /// The cookie `WhoIsSignedIn` reads, read the same way.
        private func hasSession(_ webView: WKWebView) async -> Bool {
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            return cookies.contains {
                $0.name == WhoIsSignedIn.cookie && $0.domain.hasSuffix("instagram.com")
            }
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
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

            switch ContentRules.routing(for: url) {
            case .allow:
                // Anything that is part of signing in, and anything in a frame,
                // goes ahead without a question.
                guard isMainFrame, !ContentRules.isSignInFlow(url) else {
                    decisionHandler(.allow)
                    return
                }
                // A page of Instagram's that is not part of signing in. With a
                // session behind it, that is the sign-in over, and the page
                // belongs in a pane. Without one, it is a link somebody tapped
                // on the form — the help pages, the terms — and it opens here.
                Task {
                    let over = await finishIfOver(at: url, in: webView)
                    decisionHandler(over ? .cancel : .allow)
                }

            case let .refuse(blocked):
                decisionHandler(.cancel)
                // The form offers a button into Instagram's own app, and it is
                // refused here for the reason it is refused everywhere.
                if isMainFrame { session.report(blocked) }

            case .openOutside:
                guard isMainFrame else {
                    decisionHandler(.allow)
                    return
                }
                decisionHandler(.cancel)
                handOff(url)

            case .ignore:
                decisionHandler(.cancel)
            }
        }

        /// Links that ask for a new window get this one, under the same rules.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                switch ContentRules.routing(for: url) {
                case .allow: webView.load(URLRequest(url: url))
                case let .refuse(blocked): session.report(blocked)
                case .openOutside: handOff(url)
                case .ignore: break
                }
            }
            return nil
        }

        /// Everything handed to Safari from here is handed away from inside a
        /// sign-in, so it always says so. See `WebPane.handOff`.
        private func handOff(_ url: URL) {
            surface.note(handedOff: url)
            session.show(String(
                localized: "\(url.host ?? "That page") is not part of Instagram, so it opened in Safari. If you were signing in, come back and start again."
            ))
            UIApplication.shared.open(url)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }
    }
}

/// What the strip above the sign-in page says: whose page this is, and whether
/// it arrived encrypted.
@MainActor
@Observable
final class SignInPage {
    private(set) var host: String?
    private(set) var isSecure = false

    func note(_ webView: WKWebView) {
        let url = webView.url
        let host = url?.host?.lowercased()
        let secure = url?.scheme?.lowercased() == "https" && webView.hasOnlySecureContent
        if self.host != host { self.host = host }
        if isSecure != secure { isSecure = secure }
    }
}

/// When a page belongs on the sign-in screen, and when the sign-in is over.
///
/// Its own type, with no web view in it, so that both answers can be tested.
enum SignIn {
    /// Whether a pane's page should be opened on the sign-in screen instead.
    ///
    /// Instagram's own sign-in pages only — the login form, two-factor, a
    /// security check, a password, Accounts Center. Facebook's and Meta's
    /// pages are part of `ContentRules.isSignInFlow` too, because a sign-in
    /// passes through them; but a pane only ever reaches one of those by
    /// somebody following a link, and a link to Facebook is not a sign-in.
    static func belongsHere(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased() else { return false }
        let isInstagram = host == "instagram.com" || host.hasSuffix(".instagram.com")
        return isInstagram && ContentRules.isSignInFlow(url)
    }

    /// Whether the sign-in is over: a page of Instagram's that is not part of
    /// signing in, with a session in the store.
    ///
    /// Both halves, because either alone is wrong. A session alone is
    /// somebody halfway through two-factor, already holding a cookie. A page
    /// alone is somebody signed out reading Instagram's help pages.
    static func isOver(at url: URL?, hasSession: Bool) -> Bool {
        guard hasSession, let url, let host = url.host?.lowercased(),
              ContentRules.isInternal(host: host) else { return false }
        return !ContentRules.isSignInFlow(url)
    }
}
