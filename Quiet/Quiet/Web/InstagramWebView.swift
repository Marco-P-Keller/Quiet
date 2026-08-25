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

    /// The signed-in username, read out of Instagram's own navigation before
    /// that row is taken out. `nil` until a page carrying it has loaded, which
    /// is why the profile entry in Quiet's row appears a moment after the rest.
    ///
    /// Starts as the name the last run learned, so the last entry in the row is
    /// there from the first frame instead of appearing a second in.
    private(set) var me: String? = Remembered.me()

    /// Your own face, for the last entry in the row — because Instagram's ends
    /// in a photograph rather than an outline of a person.
    private(set) var myFace: UIImage? = Remembered.myFace()

    /// The address on screen.
    ///
    /// Kept for one reason: the row along the bottom marks where you are, the
    /// way Instagram's does, and it cannot mark what it does not know. Read
    /// when a navigation commits rather than when one is asked for, because a
    /// signed-in session asks for the login form and is handed the feed.
    private(set) var address: URL?

    /// Whether the row has drawn itself in, because somebody is reading.
    ///
    /// Only the island does anything with this. It never leaves — a control
    /// that disappears is a control you hunt for — but while the page is moving
    /// away under your thumb there is no reason for it to be at full size. The
    /// bar ignores it: a bar standing on the bottom edge has nothing to float
    /// over and nothing to get out of the way of.
    private(set) var isBarCollapsed = false

    /// Instagram's own icons, drawn by Instagram.
    ///
    /// Keyed "home.on", "home.off" and so on. Instagram fills the entry you are
    /// standing on and outlines the rest, so a row read on the feed gives a
    /// filled house and outlines for everything else; walk to the inbox and the
    /// other halves arrive. Both collect themselves as the app is used, and
    /// whichever has not turned up yet falls back to the symbol Quiet drew.
    ///
    /// They start as whatever the last run learned, so the row is right in its
    /// first frame rather than a second later. See `Remembered`.
    private(set) var icons: [String: UIImage] = Remembered.icons()

    /// Which glyphs this run has heard from Instagram itself.
    ///
    /// A remembered glyph is used until Instagram sends its own, and then
    /// replaced — once per run, so a page that rewrites its navigation forty
    /// times does not decode forty pictures. Without this, an icon Instagram
    /// redrew would be one Quiet went on showing the old version of for ever.
    @ObservationIgnored private var heard: Set<String> = []

    func icon(_ entry: String, on: Bool) -> UIImage? {
        icons[entry + (on ? ".on" : ".off")]
    }

    /// The colour Instagram is drawing its own chrome in, as the page reports it.
    ///
    /// The band behind the clock is painted in this. The app owns those pixels —
    /// the page's viewport starts underneath them — so something has to decide
    /// what colour they are, and a hex written into the app is a guess about
    /// somebody else's design that goes stale without anyone noticing. The page
    /// is asked instead. See `sayChrome` in trim.js.
    ///
    /// `nil` until a page has answered, and after a page that has nothing to
    /// say: the band falls back to the system's own grey, which is close enough
    /// that the change is not something you can catch happening.
    private(set) var chrome: Color?

    /// Whether Instagram has a sheet or a dialog up.
    ///
    /// A sheet is not a page and carries no address, so nothing about where you
    /// are can see one coming — and Instagram puts one up for switching
    /// accounts, for sharing, for the menu behind the three dots. It slides
    /// over its own tab bar the way every sheet on a phone does, and Quiet's
    /// row was staying where it was and being drawn through the buttons on it.
    ///
    /// Read from the page, which is the only place it exists. See `trim.js`.
    private(set) var isSheetUp = false

    /// The colour the sheet on screen is drawn in, so the app can paint the
    /// strip of glass it takes away underneath it. `nil` when there is no sheet
    /// or the page had nothing opaque to report.
    private(set) var sheetTint: Color?

    /// Whether the sheet on the screen is standing clear of the row.
    ///
    /// The page makes the room now: it is told how much of the bottom of the
    /// glass the row stands on, and pads the panel of the sheet by exactly
    /// that, so the buttons end above the row and the sheet's own colour runs
    /// on beneath it. Then the row is beside the sheet rather than over it, and
    /// has no reason to stop answering taps.
    ///
    /// It cannot always be done — a sheet that fills the glass, or one built in
    /// a shape the page cannot recognise — and this is how the page says so.
    /// Where the room was not made the row stands down and lets the press go
    /// through to whatever is underneath it, which is what it did for every
    /// sheet before the room existed.
    ///
    /// True while there is no sheet, because a screen with nothing modal on it
    /// has nothing standing in the row's way.
    private(set) var isSheetClear = true

    /// False until the first page has finished, or failed. While it is false the
    /// browsing screen keeps Quiet's own paper over the top, so a cold launch
    /// shows a considered blank rather than the white rectangle of a web view
    /// that has not painted yet.
    private(set) var hasLoaded = false

    func open(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    /// Ask for the page again.
    ///
    /// What the pull at the top of the feed does, and the only way back from a
    /// page that failed to arrive — a web view that could not load has an
    /// address but nothing on it, and `reload` is the request that fixes both.
    /// Falls back to the home address for the one case where there is nothing
    /// to reload, which is a cold view nobody has navigated yet.
    func reload() {
        guard let webView else { return }
        if webView.url == nil {
            webView.load(URLRequest(url: ContentRules.home))
        } else {
            webView.reload()
        }
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

    fileprivate func note(path: String) {
        guard let url = URL(string: path, relativeTo: ContentRules.feed)?.absoluteURL else { return }
        note(address: url)
    }

    fileprivate func note(address url: URL?) {
        guard address != url else { return }
        address = url
    }

    fileprivate func setBar(collapsed: Bool) {
        guard collapsed != isBarCollapsed else { return }
        isBarCollapsed = collapsed
    }

    fileprivate func note(icon entry: String, picture: String) {
        guard !heard.contains(entry),
              let data = Data(base64Encoded: picture),
              let image = UIImage(data: data) else { return }
        heard.insert(entry)
        // A template, so the row tints it with everything else rather than
        // carrying Instagram's black into a light appearance.
        icons[entry] = image.withRenderingMode(.alwaysTemplate)
        Remembered.remember(icon: entry, data: data)
    }

    fileprivate func note(sheet up: Bool, clear: Bool, tint: Color?) {
        if sheetTint != tint { sheetTint = tint }
        note(sheet: up, clear: clear)
    }

    fileprivate func note(sheet up: Bool, clear: Bool) {
        guard isSheetUp != up || isSheetClear != clear else { return }
        isSheetUp = up
        isSheetClear = clear
    }

    fileprivate func note(chrome colour: Color) {
        guard chrome != colour else { return }
        chrome = colour
    }

    fileprivate func note(me name: String, picture: String?) {
        if me != name { me = name }
        let data = picture.flatMap { Data(base64Encoded: $0) }
        if let data, let face = UIImage(data: data) { myFace = face }
        Remembered.remember(me: name, face: data)
    }

    /// Where Quiet's own row can send you.
    ///
    /// Through Instagram's own row rather than by loading an address. Loading
    /// one throws the page away and builds it again — a spinner, the feed from
    /// the top, the stories fetched a second time — every time you come back
    /// from the inbox. Pressing the link the site already has hands the address
    /// to the client running in the page, which keeps its shell, its caches and
    /// the place you had scrolled to.
    ///
    /// The address is the fallback, for the pages that carry no such row and for
    /// the moment before the first one has loaded.
    func goToFeed() { go("home", or: ContentRules.feed) }
    func goToMessages() { go("messages", or: ContentRules.messages) }

    func goToMyProfile() {
        go("profile", or: me.flatMap(ContentRules.profile(forHandle:)))
    }

    private func go(_ kind: String, or address: URL?) {
        guard let webView else { return }
        Task { @MainActor in
            let answered = try? await webView.evaluateJavaScript(
                "window.__quietGo ? window.__quietGo('\(kind)') : false"
            )
            // A string is the address the page went to; anything else means
            // there was no row to press.
            if let went = answered as? String, !went.isEmpty { return }
            if let address { open(address) }
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

    /// The notch, and nothing at the bottom.
    ///
    /// This is where the black band above the row actually came from, and it
    /// took three commits to find because the app never asked for it. The page
    /// is told to cover the glass — `viewport-fit=cover`, set by trim.js — so
    /// that trim.css can ask about the notch and keep Instagram's header off
    /// the clock. Switching that on switches on *every* rule that consults the
    /// safe area, at both ends: `env(safe-area-inset-bottom)` stopped reading
    /// zero, and every reservation Instagram makes for the home indicator came
    /// back as a strip of nothing under Quiet's row, where the next photograph
    /// belongs.
    ///
    /// A stylesheet cannot answer that. `env()` is not a property to override
    /// and the elements that consult it are somebody else's, all over the page.
    /// So it is answered here instead, at the source both WebKit and the page
    /// read from: this view has a top inset and no bottom one. The clock keeps
    /// its number, and nothing anywhere is asked to keep clear of a strip that
    /// Quiet's own row is deliberately floating over.
    override var safeAreaInsets: UIEdgeInsets {
        var insets = super.safeAreaInsets
        insets.bottom = 0
        return insets
    }

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
    ///
    /// Both ends are the scroll indicator's business, and the bottom is the
    /// page's as well: the row is opaque, so the last post has to be able to
    /// scroll clear of it rather than sitting behind it for ever. That is what
    /// every bar along the bottom of an iPhone has done since the first one.
    var inset: UIEdgeInsets

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, surface: surface)
    }

    func makeUIView(context: Context) -> WKWebView {
        // The larger of what the layout has worked out and what the window
        // knows. On the first pass the layout has worked out nothing and is
        // still holding the twenty points the state starts at, while the window
        // has had the real number since it opened.
        // Whatever the screen is asked to keep clear, which is now nothing:
        // the view starts below the clock, so the page's own world already
        // does. Kept as a number rather than deleted because the mechanism is
        // the right one for anything the app ever does need the page to know.
        let top = inset.top
        context.coordinator.top = top
        // And what the row stands on at the other end, which the page needs for
        // one thing only: keeping a sheet's own buttons off it.
        context.coordinator.row = inset.bottom
        let payload = WebScripts.load(top: top, row: inset.bottom)

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
        // `WebScripts.load(top:row:)`: the first thing in the feed starts
        // below the status bar and scrolls up behind it. That is what
        // Instagram does, and it is a property of the page rather than of the
        // view.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // And the app's own, which is the other half of the same request: the
        // page's are turned off in trim.css, and this is the one WebKit draws
        // over the top of them.
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: inset.bottom, right: 0)
        // The indicator is the one thing that should still respect the app's
        // furniture: a scroll bar running under the row reads as a fault.
        webView.scrollView.verticalScrollIndicatorInsets = inset
        webView.load(URLRequest(url: ContentRules.home))

        context.coordinator.watch(webView.scrollView)
        context.coordinator.addPull(to: webView.scrollView)
        surface.adopt(webView, missing: payload.missing)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.scrollView.verticalScrollIndicatorInsets != inset {
            webView.scrollView.verticalScrollIndicatorInsets = inset
        }
        if webView.scrollView.contentInset.bottom != inset.bottom {
            webView.scrollView.contentInset.bottom = inset.bottom
        }
        // The same larger-of-the-two as in `makeUIView`, so that a layout pass
        // that still reports the starting twenty points cannot walk the number
        // back down again once the window has given the real one.
        // Whatever the screen is asked to keep clear, which is now nothing:
        // the view starts below the clock, so the page's own world already
        // does. Kept as a number rather than deleted because the mechanism is
        // the right one for anything the app ever does need the page to know.
        let top = inset.top
        // The row's height changes under the same hand as the inset above it:
        // the two shapes it can be drawn in are a setting, and a story or a
        // conversation has no row at all. A sheet that is open across either
        // change should be given the room the row is actually standing on.
        if context.coordinator.top != top || context.coordinator.row != inset.bottom {
            context.coordinator.top = top
            context.coordinator.row = inset.bottom
            context.coordinator.tellEveryPage(webView, top: top, row: inset.bottom)
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
        /// Watching the page move, so the island can get out of the way a
        /// little.
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

        // MARK: - The pull at the top

        /// Scrolled to the top and then pulled further: the page is asked for
        /// again. What Instagram's own app does, and what every list on this
        /// phone has done for fifteen years.
        ///
        /// This is `UIRefreshControl` rather than anything of Quiet's, and it
        /// is the system's on purpose. The gesture has a feel — where it
        /// catches, when it lets go, what it does under a thumb that changes
        /// its mind halfway — and a hand-drawn imitation gets one of those
        /// wrong and reads as a cheap copy of a thing everybody already knows.
        ///
        /// It lands in the right place without being told to. The web view
        /// starts below the clock rather than behind it — see `BrowserScreen`,
        /// which hands it the glass less the status bar — so the top of this
        /// scroll view is already the top of the page as a person sees it, and
        /// the spinner comes down into the page instead of into the time.
        private var pull: UIRefreshControl?

        func addPull(to scrollView: UIScrollView) {
            let control = UIRefreshControl()
            // Over Instagram's page rather than over Quiet's paper, so it takes
            // the system's colour the way the view underneath it does.
            control.tintColor = .secondaryLabel
            control.addTarget(self, action: #selector(pulled), for: .valueChanged)
            pull = control
            keepPullAlive(scrollView)
        }

        /// Said again, and again, because WebKit says otherwise.
        ///
        /// This is why the first version of this did nothing. Setting the
        /// control up once, on a view that has not loaded anything yet, is the
        /// recipe everybody writes down and it is half the job: a page load
        /// takes the bounce back. WebKit decides for itself whether the scroll
        /// view may be pulled past its own edges, out of the document it just
        /// committed, and it does not ask what the app had set before. A
        /// control attached to a scroll view that cannot be overscrolled is a
        /// control that is never reached — no spinner, no reload, and nothing
        /// anywhere saying why.
        ///
        /// So it is asserted on every ending a navigation has, and on every
        /// scroll besides. Instagram's client changes pages without loading
        /// anything, and a navigation delegate hears nothing at all about those
        /// — the same reason the row along the bottom is told where it is by
        /// the page rather than by the app. Two boolean reads per frame is not
        /// a cost worth a cleverer answer.
        ///
        /// Both spellings. `bounces` is the one that has always meant this, and
        /// since iOS 16 it is `alwaysBounceVertical` that actually decides —
        /// which also covers a page shorter than the screen, where there would
        /// otherwise be nothing to pull against on a profile with four posts.
        func keepPullAlive(_ scrollView: UIScrollView) {
            // Not on a story or inside a conversation. See `ContentRules`.
            guard !ContentRules.isImmersive(surface.address) else {
                if scrollView.refreshControl != nil { scrollView.refreshControl = nil }
                return
            }
            if scrollView.refreshControl !== pull { scrollView.refreshControl = pull }
            if !scrollView.bounces { scrollView.bounces = true }
            if !scrollView.alwaysBounceVertical { scrollView.alwaysBounceVertical = true }
        }

        @objc private func pulled() {
            surface.reload()
        }

        /// Let the spinner go.
        ///
        /// Called from every ending a navigation has, including the cancelled
        /// one that is otherwise ignored: a pull that is answered by a
        /// redirect, or by a person tapping something while the page comes
        /// back, still has to give the control back. A spinner left turning
        /// over a page that has finished is the app claiming to be busy.
        func endPull() {
            guard let pull, pull.isRefreshing else { return }
            pull.endRefreshing()
        }

        private func scrolled(_ scrollView: UIScrollView) {
            keepPullAlive(scrollView)

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

        /// And how much of the bottom of the glass Quiet's row stands on, which
        /// the page is told for the sake of the one thing in it that is pinned
        /// to that edge: a sheet. See `WebScripts.load(top:row:)`.
        var row: CGFloat = 0

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
        func tellEveryPage(_ webView: WKWebView, top: CGFloat, row: CGFloat) {
            let controller = webView.configuration.userContentController
            controller.removeAllUserScripts()
            WebScripts.load(top: top, row: row).scripts.forEach(controller.addUserScript)
        }

        /// And the document already on screen, whose scripts have run.
        ///
        /// Said again on every commit rather than once, because the page that
        /// matters most is the one loading while the number is still unknown.
        func tellThisPage(_ webView: WKWebView) {
            var lines: [String] = []
            // Nothing at all rather than a zero: on a page that has painted,
            // zero is never the height of a status bar, and writing it would
            // put the header back under the clock for a frame.
            if top > 0 {
                let points = Int(top.rounded())
                lines.append("""
                window.__quietTop = \(points);
                document.documentElement.style.setProperty("--quiet-top", "\(points)px");
                """)
            }
            // Zero, on the other hand, is exactly what the row is on a story
            // and in a conversation, and a page that kept the last screen's
            // number would hold a sheet off an edge nothing is standing on.
            let stands = Int(row.rounded())
            lines.append("""
            window.__quietRow = \(stands);
            document.documentElement.style.setProperty("--quiet-row", "\(stands)px");
            """)
            webView.evaluateJavaScript(lines.joined(separator: "\n"))
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
            keepPullAlive(webView.scrollView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            surface.note(address: webView.url)
            surface.markLoaded()
            tellThisPage(webView)
            endPull()
            keepPullAlive(webView.scrollView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            endPull()
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
            endPull()
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

            case "where":
                // Instagram's client changes the address without loading
                // anything, so this is the only way the row learns it moved.
                if let path = body["path"] as? String {
                    surface.note(path: path)
                }

            case "icon":
                // One glyph out of the row Quiet hides, rasterised by the page.
                if let entry = body["entry"] as? String,
                   let picture = body["picture"] as? String {
                    surface.note(icon: entry, picture: picture)
                }

            case "chrome":
                // The colour of Instagram's own chrome, for the band the clock
                // stands on. Sent again whenever it changes, which is how the
                // band follows the phone from light to dark.
                if let colour = Chrome.colour(in: body) {
                    surface.note(chrome: colour)
                }

            case "me":
                // Read out of Instagram's navigation before it was taken out.
                if let name = body["username"] as? String {
                    surface.note(me: name, picture: body["picture"] as? String)
                }

            case "sheet":
                // Whether something modal is up, and whether the page managed
                // to give it room to stand clear of Quiet's row.
                surface.note(
                    sheet: body["up"] as? Bool ?? false,
                    // A page from before this existed says nothing about the
                    // room, and the honest reading of silence is that none was
                    // made: the row stands down, which is never wrong, only
                    // occasionally more careful than it needs to be.
                    clear: body["clear"] as? Bool ?? false,
                    // What colour it is, so the strip of glass the app takes
                    // away underneath it is painted in the sheet's own colour
                    // rather than showing as a band of something else.
                    tint: Chrome.colour(in: body)
                )

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

/// Three numbers from the page, turned into a colour, or nothing.
///
/// Its own type so that the refusals can be tested without a web view: a
/// channel missing, a channel that is not a number, a channel outside the range
/// a channel has. A message that arrives malformed leaves the band on the
/// colour it already had, which is the one behaviour that is never wrong.
enum Chrome {
    static func colour(in body: [String: Any]) -> Color? {
        guard let red = channel(body["red"]),
              let green = channel(body["green"]),
              let blue = channel(body["blue"]) else { return nil }
        return Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// 0...255 out of the page, 0...1 for SwiftUI.
    private static func channel(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let raw = number.doubleValue
        guard raw.isFinite, (0...255).contains(raw) else { return nil }
        return raw / 255
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
