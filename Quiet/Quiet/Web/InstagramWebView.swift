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

    /// The address on screen.
    ///
    /// Kept for one reason: the row along the bottom marks where you are, the
    /// way Instagram's does, and it cannot mark what it does not know. Read
    /// when a navigation commits rather than when one is asked for, because a
    /// signed-in session asks for the login form and is handed the feed.
    private(set) var address: URL?

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

    fileprivate func note(path: String) {
        guard let url = URL(string: path, relativeTo: ContentRules.feed)?.absoluteURL else { return }
        note(address: url)
    }

    fileprivate func note(address url: URL?) {
        guard address != url else { return }
        address = url
    }

    fileprivate func note(me name: String, picture: String?) {
        if me != name { me = name }
        guard let picture, let data = Data(base64Encoded: picture) else { return }
        myFace = UIImage(data: data)
    }

    /// Where Quiet's own row can send you.
    func goToFeed() { open(ContentRules.feed) }
    func goToMessages() { open(ContentRules.messages) }

    /// Your own profile.
    ///
    /// Instagram's own link first, taken from the row Quiet hides — which is
    /// hidden rather than removed precisely so it still knows where it goes.
    /// A name the app read a moment too early builds an address to a stranger
    /// or to nothing, and this button is the one place in Quiet where that is
    /// unforgivable.
    ///
    /// The address built from the name is the fallback, for the pages that
    /// carry no such row.
    func goToMyProfile() {
        guard let webView else { return }
        Task { @MainActor in
            let answered = try? await webView.evaluateJavaScript(
                "window.__quietOpenProfile ? window.__quietOpenProfile() : false"
            )
            // A string is the address the page went to; anything else means
            // there was no row to read and the name is all there is.
            if let went = answered as? String, !went.isEmpty { return }
            guard let me, let url = ContentRules.profile(forHandle: me) else { return }
            open(url)
        }
    }
}

/// A web view that says when iOS has worked out how tall the status bar is.
///
/// The page has to be told that number — it starts the feed below the clock
/// with it — and the app has now got it wrong twice from two different
/// directions. Asking the window gives twenty points until something has been
/// laid out, and a SwiftUI state that starts at twenty and is corrected on
/// appear is corrected after the scripts have already been built out of it.
///
/// This is the one source that cannot be early: it is UIKit telling the view
/// that owns the pixels what its own safe area is, at the moment it knows.
final class QuietWebView: WKWebView {
    var onSafeArea: ((UIEdgeInsets) -> Void)?

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onSafeArea?(safeAreaInsets)
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
        // The larger of what the layout has worked out and what the window
        // knows. On the first pass the layout has worked out nothing and is
        // still holding the twenty points the state starts at, while the window
        // has had the real number since it opened.
        let top = max(inset.top, SafeArea.top)
        context.coordinator.top = top
        let payload = WebScripts.load(top: top)

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

        let webView = QuietWebView(frame: .zero, configuration: configuration)
        webView.onSafeArea = { [weak webView] insets in
            guard let webView else { return }
            context.coordinator.learn(top: insets.top, on: webView)
        }
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = UserAgent.mobileSafari(systemVersion: UIDevice.current.systemVersion)
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        // The page is given the whole screen. All of it.
        //
        // Seven attempts went into the half-inch of glass above the feed, and
        // every one of them took something away from the page in order to keep
        // the clock legible — a shorter view, a viewport-fit, a content inset,
        // a band of the app's own drawn over the top. The photograph that
        // settled it shows why they were all wrong: whatever is taken off the
        // top comes back as a black strip at the bottom, above the row, where
        // Instagram runs its next photograph.
        //
        // So nothing is taken. The web view owns every pixel, the page fills
        // it, and content runs behind the status bar and beneath the row the
        // way it does in Instagram's own app. What keeps the clock legible is
        // a top padding on the document itself, handed to the page in
        // `WebScripts.load(top:)`: the first thing in the feed starts below the
        // status bar and scrolls up behind it. That is what Instagram does, and
        // it is a property of the page rather than of the view.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        // The indicator is the one thing that should still respect the app's
        // furniture: a scroll bar running under the row reads as a fault.
        webView.scrollView.verticalScrollIndicatorInsets = inset
        webView.load(URLRequest(url: ContentRules.home))

        context.coordinator.watch(webView.scrollView)
        surface.adopt(webView, missing: payload.missing)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.scrollView.verticalScrollIndicatorInsets != inset {
            webView.scrollView.verticalScrollIndicatorInsets = inset
        }
        // The same larger-of-the-two as in `makeUIView`, so that a layout pass
        // that still reports the starting twenty points cannot walk the number
        // back down again once the window has given the real one.
        let top = max(inset.top, SafeArea.top)
        if context.coordinator.top != top {
            context.coordinator.top = top
            context.coordinator.tellEveryPage(webView, top: top)
            context.coordinator.tellThisPage(webView)
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

        /// How tall this phone's status bar is, once anybody knows.
        ///
        /// Zero until the first layout pass, which is the whole difficulty
        /// below: the scripts are built and the first page is asked for before
        /// this number exists.
        var top: CGFloat = 0

        /// Rebuild the injected scripts around the real number, so that every
        /// page from here on is told it before its first paint.
        ///
        /// This is the half that was missing, and it cost the app the top half
        /// inch of every screen. The scripts are built once, in `makeUIView`,
        /// out of whatever the status bar height was at that moment — which is
        /// the twenty points the state starts at, because the window has not
        /// laid anything out yet. The real number arrived a moment later and
        /// was handed to the page with `evaluateJavaScript`, and that is the
        /// trap: the page it reached was the empty one the web view starts on.
        /// Instagram's document committed afterwards, ran the injected script
        /// again, and set the twenty points back.
        ///
        /// So the number was never wrong for long. It was right on a document
        /// nobody ever saw, and twenty points on the one everybody did — about
        /// seven points of clearance for a fifty-nine point status bar, which
        /// is the collision in the photograph.
        func tellEveryPage(_ webView: WKWebView, top: CGFloat) {
            let controller = webView.configuration.userContentController
            controller.removeAllUserScripts()
            WebScripts.load(top: top).scripts.forEach(controller.addUserScript)
        }

        /// A better answer than the one being used, from whichever direction
        /// it arrives.
        ///
        /// Only ever upward. The floor is twenty points, which is the shortest
        /// status bar any iPhone has, so a source that has not woken up yet
        /// cannot walk a correct answer back down to its own default — which is
        /// exactly how a fifty-nine point status bar ended up being told it was
        /// twenty.
        func learn(top candidate: CGFloat, on webView: WKWebView) {
            let next = max(top, candidate)
            guard next != top else { return }
            top = next
            tellEveryPage(webView, top: next)
            tellThisPage(webView)
        }

        /// And the document already on screen, whose scripts have run.
        ///
        /// Said again on every commit rather than once, because the page that
        /// matters most is the one loading while the number is still unknown.
        func tellThisPage(_ webView: WKWebView) {
            guard top > 0 else { return }
            let points = Int(top.rounded())
            webView.evaluateJavaScript(
                """
                window.__quietTop = \(points);
                document.documentElement.style.setProperty("--quiet-top", "\(points)px");
                """
            )
        }

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

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            surface.note(address: webView.url)
            tellThisPage(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            surface.note(address: webView.url)
            surface.markLoaded()
            tellThisPage(webView)
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

            case "where":
                // Instagram's client changes the address without loading
                // anything, so this is the only way the row learns it moved.
                if let path = body["path"] as? String {
                    surface.note(path: path)
                }

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
