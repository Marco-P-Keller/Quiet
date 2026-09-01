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

    /// The three pages, and which of them is on the glass.
    ///
    /// Weak for the same reason the view above is: the browsing screen owns
    /// both, and a surface that outlived the screen holding a strong reference
    /// to it would be holding three copies of Instagram open behind a curtain.
    /// Everything below still speaks to one web view — this only decides which
    /// one that is. See `PaneStack`.
    @ObservationIgnored fileprivate weak var stack: PaneStack?

    /// Which of Instagram's three the row should be marking.
    ///
    /// Read off the pane rather than off the address, which is the change the
    /// panes brought with them. A tab bar marks the tab you are standing in,
    /// not the page you have wandered to inside it: tap a friend in the feed
    /// and you are still standing in **home**, the way you are still standing
    /// in a tab on every phone ever made. The address said otherwise, and had
    /// to — with one page there was nothing else to ask.
    private(set) var pane: Pane = .home

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

    /// Whether a field on the page has the keyboard.
    ///
    /// The same message the session uses to hold the curtain for one sentence,
    /// read here for a second reason: the row steps aside while somebody is
    /// writing. A comment box, a message, a search field — all of them are
    /// pinned to the bottom of the page, which is exactly where a floating row
    /// is, and a send button under a pill is a send button nobody can press.
    private(set) var isTyping = false

    /// Whether Instagram has something modal up.
    ///
    /// Read from the page, which is the only place it exists, and used for one
    /// thing: Quiet's own row steps aside while it is true. Nothing of
    /// Instagram's is touched to make that happen — see the sheet section in
    /// `trim.js` for why that distinction is the whole of it.
    private(set) var isSheetUp = false

    /// False until the first page has finished, or failed. While it is false the
    /// browsing screen keeps Quiet's own paper over the top, so a cold launch
    /// shows a considered blank rather than the white rectangle of a web view
    /// that has not painted yet.
    private(set) var hasLoaded = false

    /// Whether the page has anything on it — a picture, a glyph, a word.
    ///
    /// `hasLoaded` answers a question about a request, and a request finishing
    /// is not the same event as a page appearing. Instagram is a shell: the
    /// navigation settles, the cover comes off, and what is on the glass for
    /// the next second or two is Instagram's own black rectangle with nothing
    /// in it. A photograph of that is why this exists — a black void under a
    /// grey band, which reads as a broken app rather than a loading one.
    ///
    /// So the cover stays up until the page says it has drawn something. The
    /// page only ever says this on the way up: it goes quiet for good the
    /// first time there is something to see, so a client-side move between
    /// pages — which empties Instagram's own main element for a frame — can
    /// never bring the cover back over a page somebody is reading. See
    /// `sayBare` in trim.js.
    ///
    /// False until the page says otherwise, which is deliberate: a page whose
    /// script never ran cannot answer, and a cover held up forever over one is
    /// worse than the black rectangle. That case has its own screen anyway —
    /// see `stumble`.
    private(set) var isBare = false

    func open(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    /// Ask for the page again.
    ///
    /// What the pull at the top of the feed does, and the only way back from a
    /// page that failed to arrive — a web view that could not load has an
    /// address but nothing on it, and `reload` is the request that fixes both.
    /// Falls back to that pane's own opening address for the one case where
    /// there is nothing to reload, which is a view nobody has navigated yet.
    ///
    /// The pane in front, and only that one. **Try again** is somebody looking
    /// at a page that did not arrive, and the inbox two taps away is not the
    /// page they are looking at. See `WebPane.startAgain`.
    func reload() {
        stack?.reloadWhatIsInFront()
    }

    /// What a tap on the status bar has always done.
    /// Write down where you are, because the app may not be given a say in
    /// coming back.
    ///
    /// iOS discards a web view under memory pressure without asking, and by the
    /// time anybody notices there is nothing left to ask. So the page is put
    /// away every time the app leaves the screen, which is the last moment it
    /// is certain to be there. See `ThePlace`.
    func keepThePlace() {
        stack?.keepThePlace()
    }

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
        // Including where you were, in all three panes. A page kept from before
        // somebody signed out is a page they did not ask to see again — and an
        // inbox left standing behind a fresh login screen would be somebody
        // else's.
        ThePlace.forgetEverything()
        let store = WKWebsiteDataStore.default()
        store.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            // Every pane torn down and the home one built again from nothing,
            // rather than the current page reloaded: the other two are still
            // holding a signed-in document, and a reload of one of them would
            // put it straight back on the glass.
            self?.stack?.startOver()
            completion()
        }
    }

    /// Throw away what was only ever kept to be quick.
    ///
    /// A web view's store grows and nothing in the app ever trimmed it: months
    /// of cached pages, images and fetch responses, held for a site that
    /// changes every hour. iOS offers no way to ask how large that has become —
    /// so rather than invent a number, the app offers the thing somebody
    /// actually wants when they go looking for one.
    ///
    /// Deliberately not `allWebsiteDataTypes`, which is what signing out uses.
    /// Cookies, local storage and IndexedDB are what being signed in is *made
    /// of*, and an app that emptied them under a button called "clear cached
    /// pages" would be logging people out and calling it housekeeping.
    func clearCaches(completion: @escaping @Sendable () -> Void = {}) {
        let caches: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeServiceWorkerRegistrations,
        ]
        WKWebsiteDataStore.default().removeData(
            ofTypes: caches,
            modifiedSince: .distantPast,
            completionHandler: completion
        )
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

    /// Watching the cookie that says which account this is. Started with the
    /// first stack and never again — the browsing screen is built and taken
    /// apart with the curtain, and the question outlives both.
    @ObservationIgnored private var whoIsSignedIn: WhoIsSignedIn?

    func attach(_ stack: PaneStack) {
        self.stack = stack
        guard whoIsSignedIn == nil else { return }
        whoIsSignedIn = WhoIsSignedIn { [weak self] in
            self?.startAgainAsSomebodyElse()
        }
    }

    /// Somebody else is signed in, and every screen in the app is still the
    /// last person's.
    ///
    /// Instagram's own account switcher changes who this browser is without
    /// loading anything, so the two panes off the glass keep the feed and the
    /// inbox they had — one tap from being brought forward — and the row keeps
    /// the face. Reloading the page in front is not enough and never was: the
    /// problem is precisely the pages that are *not* in front.
    ///
    /// The order is the whole of it.
    ///
    /// The caches go first, and they go before anything is asked for again.
    /// Instagram's own service worker and fetch cache are keyed by address, and
    /// two accounts ask the same addresses — a timeline, an inbox, a profile
    /// picture — so a pane rebuilt over a warm cache can be handed the last
    /// person's answers by the app's own storage. Not `allWebsiteDataTypes`,
    /// which is what signing out uses: cookies and local storage are what being
    /// signed in is made of, and this reader has just signed *in*.
    ///
    /// Then the app forgets who it thought it was — the name, the face, and
    /// every pane's saved place, because a place is a page from before the
    /// switch and restoring one puts the old account back on the glass without
    /// a single request ever asking whether it was still theirs.
    ///
    /// And only then are the panes torn down and the feed built again from
    /// nothing.
    private func startAgainAsSomebodyElse() {
        NSLog("Quiet: the account changed; starting every pane again")
        clearCaches { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.me = nil
                self.myFace = nil
                Remembered.forgetMe()
                ThePlace.forgetEverything()
                self.stack?.startOver()
            }
        }
    }

    /// Point at a pane.
    ///
    /// It used to reset `hasLoaded` and `isBare`, because the only view it was
    /// ever handed was a new one. It must not now: a pane coming back to the
    /// glass finished loading minutes ago, and wiping those two would drop
    /// Quiet's own cover over a page that is sitting there ready — which is the
    /// exact flicker the panes exist to remove. What each pane knows about
    /// itself is pushed in straight afterwards. See `WebPane.takeTheGlass`.
    fileprivate func adopt(_ webView: WKWebView, missing: [String]) {
        self.webView = webView
        missingResources = missing
    }

    func note(pane: Pane) {
        guard self.pane != pane else { return }
        self.pane = pane
    }

    /// Called when a navigation settles, whether it worked or not. A failed
    /// load must lift the cover too, or a person offline would be left looking
    /// at an empty page with no explanation.
    fileprivate func note(loaded: Bool) {
        guard hasLoaded != loaded else { return }
        hasLoaded = loaded
    }

    fileprivate func note(bare: Bool) {
        guard isBare != bare else { return }
        isBare = bare
    }

    fileprivate func note(address url: URL?) {
        guard address != url else { return }
        address = url
    }

    /// What stopped the page arriving, when nothing arrived at all.
    ///
    /// Only for the case where there is no page underneath: a failure while
    /// something is already on screen is a notice, because replacing a page
    /// somebody is reading with an apology loses them their place over a
    /// request they did not make.
    private(set) var stumble: StumbleView.Kind?

    fileprivate func note(stumble kind: StumbleView.Kind?) {
        #if DEBUG
        // Never over a staged photograph. See `Rehearsal.isStaged`.
        if kind != nil, Rehearsal.isStaged { return }
        #endif
        guard stumble != kind else { return }
        stumble = kind
    }

    /// Whether the trim pass is still finding anything. See `Health`.
    private(set) var health = Health()

    /// Whether WebKit accepted the block list.
    ///
    /// `nil` while nobody has answered yet, which is the first half-second of a
    /// launch. A failure here is not a crisis — the navigation delegate and the
    /// trim pass are both still standing — but it is the app running on one
    /// layer instead of two, and that is worth a line in the panel rather than
    /// a line in a log nobody reads.
    private(set) var blockListFailed = false

    fileprivate func note(blockList error: Error?) {
        let failed = error != nil
        if let error {
            NSLog("Quiet: the block list would not compile (%@)", String(describing: error))
        }
        guard blockListFailed != failed else { return }
        blockListFailed = failed
    }

    fileprivate func note(health reading: Health) {
        guard health != reading else { return }
        health = reading
    }

    /// The last address Quiet handed to Safari from inside a sign-in.
    ///
    /// Kept for one reason: it is the single most likely cause of "I cannot
    /// log in", and it is a host name — five words that turn an unreproducible
    /// report into a one-line fix. Shown in the panel, never sent anywhere.
    private(set) var handedOff: String?

    fileprivate func note(handedOff url: URL) {
        guard let host = url.host?.lowercased(), handedOff != host else { return }
        handedOff = host
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

    fileprivate func note(typing on: Bool) {
        guard isTyping != on else { return }
        isTyping = on
    }

    fileprivate func note(sheet up: Bool) {
        guard isSheetUp != up else { return }
        isSheetUp = up
    }

    fileprivate func note(chrome colour: Color) {
        guard chrome != colour else { return }
        chrome = colour
    }

    fileprivate func note(me name: String, picture: String?) {
        if me != name {
            // Somebody else. Instagram lets you change accounts without ever
            // passing through Quiet's own sign-out, and the profile pane is the
            // one page in the app that is *about* whose account this is: left
            // standing, it would go on holding the last person's photographs
            // behind an entry marked "your profile".
            //
            // The new name first, because throwing the old pane away is also
            // asking for the page that replaces it, and that page is worked out
            // from here.
            let wasSomebodyElse = me != nil
            me = name
            if wasSomebodyElse { stack?.forgetTheProfile() }
        }
        let data = picture.flatMap { Data(base64Encoded: $0) }
        if let data, let face = UIImage(data: data) { myFace = face }
        Remembered.remember(me: name, face: data)
    }

    /// Where Quiet's own row can send you.
    ///
    /// A pane each, now, so none of the three is a navigation at all: the page
    /// you are asking for is already loaded and already scrolled where you left
    /// it, and the tap is a `isHidden` on two views.
    ///
    /// The version before this pressed Instagram's own hidden link so that the
    /// site's client would move without a page load, which kept the shell and
    /// the caches. It did not keep the feed — Instagram unmounts what you left
    /// and builds it again on the way back, which is the whole of what this was
    /// for and the one thing it could not do. See `Pane`.
    func goToFeed() { stack?.show(.home) }
    func goToMessages() { stack?.show(.messages) }

    /// And the one that needs a name before it has an address.
    ///
    /// A profile pane cannot be opened until the app knows whose profile it is,
    /// and on a genuinely first launch it does not: `me` is learned from a
    /// request the first page makes, a second or so in. Remembered from then
    /// on, so this is the first second of the first launch and nothing else.
    ///
    /// In that second it does what the app did before there were panes — press
    /// Instagram's own hidden profile link in whichever pane is up. Which
    /// leaves the row marking `home` while your profile is on the glass, and
    /// that is the right way round to be wrong: the alternative is a pane that
    /// opens onto nothing.
    func goToMyProfile() {
        guard let me, ContentRules.profile(forHandle: me) != nil else {
            pressInstagramsOwn("profile")
            return
        }
        stack?.show(.profile)
    }

    /// Open an address the reader chose, in the pane it belongs to.
    ///
    /// Finding somebody is a thing you do to look at them, and looking at
    /// people is what the home pane is for — loading a stranger's profile into
    /// the inbox would leave a half-read conversation behind a page nobody
    /// asked to put there.
    ///
    /// Separate from `open` on purpose. `open` is the mechanical one — a retry,
    /// a fallback address, the page after a failure — and none of those are
    /// somebody asking to be somewhere else.
    func visit(_ url: URL) {
        stack?.show(.home)
        open(url)
    }

    /// The old mechanism, kept for the one case that still needs it.
    private func pressInstagramsOwn(_ kind: String) {
        guard let webView else { return }
        Task { @MainActor in
            _ = try? await webView.evaluateJavaScript(
                "window.__quietGo ? window.__quietGo('\(kind)') : false"
            )
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
    /// How much of the view the page is asked to keep clear, which is nothing.
    ///
    /// It was the status bar above and Quiet's row below, back when the view
    /// filled the glass and both were drawn over the top of it. The view is now
    /// a frame that starts under the clock and stops above the row, so there is
    /// no strip of it belonging to anybody else and nothing to keep clear of.
    /// Kept as a number rather than deleted because it is the right mechanism
    /// for anything the app ever does need the page to work around — and
    /// because a zero passed through a mechanism that works is safer than a
    /// mechanism deleted and written again from memory.
    var inset: UIEdgeInsets

    func makeCoordinator() -> PaneStack {
        PaneStack(session: session, surface: surface)
    }

    /// The container the panes stand in, rather than a web view.
    ///
    /// SwiftUI is handed one view whose identity never changes, and what is
    /// inside it comes and goes: the home pane at launch, the inbox the first
    /// time somebody taps it, and whichever of them a memory warning takes
    /// away. Handing SwiftUI the web views themselves would have made a tab
    /// switch a change of view identity, and a changed identity is a view
    /// rebuilt — which is the one thing that would throw the page away and undo
    /// the whole point of having three of them. See `PaneStack`.
    func makeUIView(context: Context) -> UIView {
        let stack = context.coordinator
        stack.hand(top: inset.top, inset: inset)
        stack.show(.home)
        return stack.container
    }

    func updateUIView(_ container: UIView, context: Context) {
        context.coordinator.session = session
        // Whatever the screen is asked to keep clear, which is now nothing:
        // the view starts below the clock, so the page's own world already
        // does. Kept as a number rather than deleted because the mechanism is
        // the right one for anything the app ever does need the page to know.
        //
        // Handed to every pane rather than to the one in front. A pane built
        // three taps ago was built out of the numbers that were true then, and
        // the pane nobody is looking at is the one whose wrong number nobody
        // sees until they tap it. `hand` only does the expensive half — the
        // scripts rebuilt, every page told again — when the number has actually
        // moved, because this runs on every pass SwiftUI makes over the view
        // and a page asked to run a script on every frame of every animation is
        // a page that stutters.
        context.coordinator.hand(top: inset.top, inset: inset)
    }

    @MainActor
    static func dismantleUIView(_ container: UIView, coordinator: PaneStack) {
        coordinator.dismantle()
    }

    /// What one pane knows about the page it is holding.
    ///
    /// Kept by the pane rather than written straight to the surface, which is
    /// the change three web views forced. The surface says what is happening on
    /// *the glass*, and two of the three panes are not on it — but they are
    /// still running. Instagram polls, its client moves the address, the trim
    /// pass goes on reporting what it found. A background pane allowed to speak
    /// to the surface would collapse the row, repaint the band behind the
    /// clock, or drop the "nothing arrived" screen over a page that is
    /// perfectly fine.
    ///
    /// So each pane keeps its own answers and the one in front publishes them.
    /// Which is also what makes coming back instant in the way that matters:
    /// the pane that finished loading four minutes ago says so the moment it is
    /// shown, and Quiet's cover never comes down over a page that is ready.
    struct PaneState {
        var address: URL?
        var hasLoaded = false
        var isBare = false
        var chrome: Color?
        var stumble: StumbleView.Kind?
        var isBarCollapsed = false
        var isTyping = false
        var isSheetUp = false
    }

    /// One pane: a web view, the delegates behind it, and what it knows about
    /// the page it is holding.
    ///
    /// Not called `Coordinator`, and the name is load-bearing. A type nested in
    /// a `UIViewRepresentable` and named `Coordinator` is taken as the witness
    /// for the protocol's `Coordinator` associated type — ahead of anything
    /// inferred from `makeCoordinator`. So while this was still called that,
    /// `makeCoordinator() -> PaneStack` did not satisfy the requirement and the
    /// whole conformance failed, with an error that names the protocol and says
    /// nothing about the reason.
    ///
    /// The coordinator is `PaneStack` now, because what SwiftUI coordinates
    /// with is the three of them rather than any one.
    @MainActor
    final class WebPane: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Which of the three this is, and the web view it owns.
        ///
        /// Strongly: the pane *is* the web view's lifetime. `PaneStack` holds
        /// the coordinators, and dropping one is how a page is given back to
        /// the system.
        let pane: Pane
        let webView: QuietWebView

        /// Resources that would not come out of the bundle, for this pane's
        /// scripts. Handed to the surface when the pane takes the glass.
        let missing: [String]

        /// Weakly, and `unowned` was the tempting spelling. The stack holds the
        /// coordinators, so it outlives them in every ordinary teardown — but
        /// "every ordinary teardown" is exactly the assumption that turns a
        /// delegate callback arriving one turn late into a crash rather than a
        /// no-op. A pane with no stack has no glass to be on, which is what
        /// `isLive` answers.
        private weak var stack: PaneStack?

        /// Everything this pane knows, and — when it is the one being read —
        /// everything the screen is told.
        ///
        /// Published on every change rather than diffed here. The surface's own
        /// setters all refuse a value they already hold, so saying the same
        /// thing twice costs a handful of comparisons and buys one place where
        /// the rule lives instead of eight.
        var state = PaneState() {
            didSet { if isLive { publish() } }
        }

        var isLive: Bool { stack?.isLive(pane) ?? false }

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
            guard !ContentRules.isImmersive(state.address) else {
                if scrollView.refreshControl != nil { scrollView.refreshControl = nil }
                // And give the bounce back before leaving. A conversation is a
                // list, its bottom is where it starts, and springing there is
                // what every messaging app on this phone does — but the rule
                // below may have switched it off a screen down somebody's feed
                // a moment ago, and a value left behind by another page is not
                // a decision about this one.
                if !scrollView.bounces { scrollView.bounces = true }
                return
            }
            if scrollView.refreshControl !== pull { scrollView.refreshControl = pull }

            // Both edges or neither — see `Overscroll`, which decides which of
            // the two is the one within reach. Near the top that is the top,
            // and the pull needs the bounce; a screen further down it is the
            // bottom, and under the bottom there is nothing.
            let bounce = Overscroll.bounces(
                travelled: scrollView.contentOffset.y + scrollView.adjustedContentInset.top,
                screen: scrollView.bounds.height
            )
            if scrollView.bounces != bounce { scrollView.bounces = bounce }
            if scrollView.alwaysBounceVertical != bounce {
                scrollView.alwaysBounceVertical = bounce
            }
        }

        @objc private func pulled() {
            startAgain()
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
            state.isBarCollapsed = atTop ? false : delta > 0
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
            guard !lines.isEmpty else { return }
            webView.evaluateJavaScript(lines.joined(separator: "\n"))
        }

        init(
            session: QuietSession,
            surface: WebSurface,
            stack: PaneStack,
            pane: Pane,
            top: CGFloat,
            inset: UIEdgeInsets
        ) {
            self.session = session
            self.surface = surface
            self.stack = stack
            self.pane = pane
            self.top = top
            let built = WebPane.build(top: top, inset: inset, surface: surface)
            self.webView = built.view
            self.missing = built.missing
            super.init()
            self.webView.navigationDelegate = self
            self.webView.uiDelegate = self
            // After `super.init`, because the relay needs a coordinator that
            // exists. It holds this one weakly — see `ScriptRelay`.
            self.webView.configuration.userContentController
                .add(ScriptRelay(self), name: WebScripts.messageHandler)
            watch(self.webView.scrollView)
            addPull(to: self.webView.scrollView)
        }

        /// The web view itself, built the way the app has always built it.
        ///
        /// Lifted out of `makeUIView` word for word when there came to be three
        /// of them. Every line of it was paid for once already and none of it
        /// changed on the way across; what changed is only that it happens
        /// three times instead of one, against the same persistent store, so
        /// signing in is still something you do once.
        private static func build(
            top: CGFloat,
            inset: UIEdgeInsets,
            surface: WebSurface
        ) -> (view: QuietWebView, missing: [String]) {
            let payload = WebScripts.load(top: top)

            let controller = WKUserContentController()
            payload.scripts.forEach(controller.addUserScript)

            let configuration = WKWebViewConfiguration()
            configuration.userContentController = controller
            // Persistent, so logging in is something you do once.
            configuration.websiteDataStore = .default()
            configuration.allowsInlineMediaPlayback = true
            // Nothing plays until someone asks it to. Autoplay is the smallest of
            // the hooks and among the easiest to remove.
            configuration.mediaTypesRequiringUserActionForPlayback = .all

            // The second lock, made of addresses, applied by WebKit before
            // anything of Quiet's is asked. See `BlockList` for what it does and,
            // more usefully, for what it does not.
            BlockList.install(into: configuration) { [surface] error in
                surface.note(blockList: error)
            }

            let webView = QuietWebView(frame: .zero, configuration: configuration)
            webView.allowsBackForwardNavigationGestures = true
            webView.customUserAgent = UserAgent.mobileSafari(systemVersion: UIDevice.current.systemVersion)
            // The blank between Quiet's own opening and Instagram's first paint.
            //
            // The two lines below were already here and did nothing at all, which
            // is the whole of the bug: **an opaque WKWebView never shows its own
            // background colour.** WebKit fills the view with the page's colour,
            // and a page that has not painted yet has none — so it uses its base,
            // which under a dark appearance is pure black. Every other surface in
            // the app is `Paper.ground`, a shade off black, so the launch went
            // ground, black, Instagram: one colour, a hole, and then a page.
            //
            // Asking the view not to be opaque is what makes the colour underneath
            // real. It costs a composite that WebKit was doing anyway the moment
            // anything on the page was translucent, and it buys a launch that is
            // one colour all the way through.
            webView.isOpaque = false
            webView.backgroundColor = Paper.groundColour
            webView.scrollView.backgroundColor = Paper.groundColour
            // And the strip above and below the page while it is pulled past its
            // own ends, which WebKit paints itself and would otherwise paint white.
            webView.underPageBackgroundColor = Paper.groundColour

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
            // That held for as long as the page was the only thing that could be
            // wrong about where it ended. It stopped holding at the other end of
            // the app: a sheet is anchored to the bottom of the viewport, and while
            // the viewport ran to the bottom of the glass, every sheet Instagram
            // opened arrived underneath Quiet's row. Eleven mechanisms tried to
            // move the sheet back out and each had to recognise it first, which is
            // the part that failed — in both directions.
            //
            // So the view is a frame with both ends taken off it, and the app
            // paints the two strips itself in the page's own colour. The page is
            // asked to keep clear of nothing, because nothing of it is behind
            // anything: what is fixed, what is sticky and what asks for the full
            // height are all right by construction. See the frame in
            // `BrowserScreen`.
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
            return (webView, payload.missing)
        }

        /// The first page this pane ever shows.
        ///
        /// Where you were, if you were there in the last twenty minutes.
        /// Restoring puts the page back without a load, so it is there before
        /// the first frame rather than a spinner and a feed from the top. When
        /// there is nothing to put back — a cold start, a stale place, an
        /// address the app no longer shows — this falls through to the pane's
        /// own opening address. See `ThePlace`.
        func openTheFirstPage() {
            if ThePlace.restore(into: webView, for: pane) { return }
            guard let opening = pane.opening(me: surface.me) else { return }
            webView.load(URLRequest(url: opening))
        }

        /// This pane is the one being read now. Say everything it knows.
        func takeTheGlass() {
            surface.adopt(webView, missing: missing)
            surface.note(pane: pane)
            // Whatever the keyboard was doing on this page, it is not doing it
            // now: the page has been off the glass and the field with it. The
            // session caps what typing is worth and would otherwise go on
            // holding the curtain for a sentence nobody is writing.
            if state.isTyping { state.isTyping = false }
            session.setTyping(false)
            publish()
        }

        private func publish() {
            surface.note(address: state.address)
            surface.note(loaded: state.hasLoaded)
            surface.note(bare: state.isBare)
            if let colour = state.chrome { surface.note(chrome: colour) }
            surface.note(stumble: state.stumble)
            surface.setBar(collapsed: state.isBarCollapsed)
            surface.note(typing: state.isTyping)
            surface.note(sheet: state.isSheetUp)
        }

        /// The keyboard belongs to the page on the glass, and this one is
        /// leaving it.
        func letGoOfTheKeyboard() {
            webView.endEditing(true)
            if state.isTyping { state.isTyping = false }
            session.setTyping(false)
        }

        func keepThePlace() {
            ThePlace.keep(webView, for: pane)
        }

        /// Ask for this pane's page again, whatever state it is in.
        ///
        /// What the pull at the top does, and what a pane whose web content
        /// process iOS killed needs: a view that has lost its process has an
        /// address and nothing on it, and both want the same request.
        func startAgain() {
            state.stumble = nil
            if webView.url == nil {
                openTheFirstPage()
            } else {
                webView.reload()
            }
        }

        func apply(inset: UIEdgeInsets) {
            let scrollView = webView.scrollView
            if scrollView.verticalScrollIndicatorInsets != inset {
                scrollView.verticalScrollIndicatorInsets = inset
            }
            if scrollView.contentInset.bottom != inset.bottom {
                scrollView.contentInset.bottom = inset.bottom
            }
        }

        /// Give the page back to the system.
        func dismantle() {
            scrolling?.invalidate()
            scrolling = nil
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.stopLoading()
            webView.configuration.userContentController
                .removeScriptMessageHandler(forName: WebScripts.messageHandler)
        }

        /// iOS killed this pane's web content process.
        ///
        /// Not a crash and not an error — it is the phone reclaiming memory,
        /// and with three pages open it is a thing to expect rather than a
        /// thing to be surprised by. What is left behind is a web view with an
        /// address and a blank rectangle where the page was, which is why this
        /// has to be answered rather than logged: nothing else ever will.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            stack?.died(pane)
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
                handOff(url)

            case .ignore:
                // A scheme belonging to some app on the phone. The page asked;
                // the person did not.
                decisionHandler(.cancel)
            }
        }

        /// Every page comes back saying what time it is.
        ///
        /// This is the whole of Quiet's answer to a clock pushed forward, and
        /// it costs one line of a response the app was reading anyway. No
        /// request is made, nothing is asked of anybody, and nothing leaves the
        /// phone — a `Date` header is already on the answer to a page load, put
        /// there by the server that served it.
        ///
        /// Only Instagram's own hosts, and only over HTTPS. That check lives in
        /// `ServerDate` so it can be tested without a web view.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let response = navigationResponse.response as? HTTPURLResponse,
               let instant = ServerDate.vouched(by: response) {
                session.vouchForTime(instant)
            }
            decisionHandler(.allow)
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
                    handOff(url)
                case .ignore:
                    break
                }
            }
            return nil
        }

        /// Give a page to Safari, and say so when that is about to break
        /// something.
        ///
        /// Handing anything that is not Instagram's to the system is what
        /// keeps Quiet one app rather than a browser. It has exactly one bad
        /// moment: a sign-in that passes through a domain the allowlist does
        /// not know is handed away mid-flow, Safari opens on a page that
        /// cannot finish the job, and the person comes back to a login form
        /// that has forgotten them — with nothing anywhere having said what
        /// happened.
        ///
        /// The allowlist cannot be completed by guessing. The explanation can.
        /// So a hand-off that happens while somebody is signing in names the
        /// address it gave away, and the panel keeps the last one so it can be
        /// reported rather than reconstructed from memory.
        func handOff(_ url: URL) {
            if ContentRules.isSignInFlow(state.address) {
                surface.note(handedOff: url)
                session.show(String(
                    localized: "\(url.host ?? "That page") is not part of Instagram, so it opened in Safari. If you were signing in, come back and start again."
                ))
            }
            UIApplication.shared.open(url)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Something arrived, so whatever did not arrive last time is no
            // longer the news.
            state.stumble = nil
            state.address = webView.url
            tellThisPage(webView)
            keepPullAlive(webView.scrollView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.address = webView.url
            state.hasLoaded = true
            standOnItsOwn(webView)
            tellThisPage(webView)
            endPull()
            keepPullAlive(webView.scrollView)
        }

        /// Give the fast path back, now that the page is painting its own
        /// background.
        ///
        /// The view is created transparent so that the app's own ground shows
        /// through the second before Instagram has painted anything — otherwise
        /// WebKit fills it with black and the launch has a hole in it. That
        /// transparency is not free: a view that is not opaque cannot use the
        /// fast path for its tiles, and every frame of every flick is composited
        /// over whatever is behind it. Paid for one second, that is a good
        /// trade; paid for ever, it is a stutter in the one thing this app does
        /// all day.
        ///
        /// So it is given back at the first paint and never taken again. A
        /// later navigation has a painted page underneath it already.
        private func standOnItsOwn(_ webView: WKWebView) {
            guard !webView.isOpaque else { return }
            webView.isOpaque = true
        }

        /// The page did not arrive.
        ///
        /// Two different situations wearing one error, and they want opposite
        /// answers. With a page already on screen, this is a failed reload or a
        /// tap that went nowhere: a notice, because replacing what somebody is
        /// reading with an apology loses them their place over a request they
        /// did not make. With nothing on screen — a cold launch on a train —
        /// the alternative to saying something is WebKit's own grey sentence in
        /// a white rectangle under a row that Quiet drew, which is the single
        /// most convincing way to look broken.
        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            endPull()
            let failure = error as NSError
            let code = failure.code
            guard code != NSURLErrorCancelled else { return }
            state.hasLoaded = true

            let offline = Self.offlineCodes.contains(code)
            guard webView.url == nil else {
                // Only about the page somebody is looking at. A pane off the
                // glass losing a background request is not news anybody asked
                // for, and a sentence about it would arrive over a page that is
                // loading perfectly well.
                if offline, isLive { session.show(String(localized: "No connection.")) }
                return
            }

            // Nothing on screen, and the network is there. That is the one
            // failure where a second address is worth trying: the app opens on
            // a path Instagram chose and Instagram can retire, and a retired
            // path would otherwise leave every launch on a **Try again** button
            // asking for the same dead address for ever.
            //
            // Not when offline. A phone with no network fails at the second
            // address exactly as it failed at the first, and all the attempt
            // buys is a slower way to say the true thing.
            //
            // The address that failed comes out of the error rather than off
            // the view, which by now is holding nothing.
            let failed = failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL
            if !offline, let next = ContentRules.opening(after: failed) {
                webView.load(URLRequest(url: next))
                return
            }

            state.stumble = offline ? .offline : .unreachable
        }

        /// The codes that mean "there is no network", as against the ones that
        /// mean "the network is there and something else went wrong". Only the
        /// difference between those two ever reaches a person, because no
        /// further detail turns into a sentence that helps anybody.
        private static let offlineCodes: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDataNotAllowed,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorCallIsActive,
        ]

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            state.hasLoaded = true
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
                    state.address = URL(string: path, relativeTo: ContentRules.feed)?.absoluteURL
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
                    state.chrome = colour
                }

            case "bare":
                // Whether Instagram has drawn anything yet. The cover over the
                // top of it stays up until this says there is something to see.
                state.isBare = body["on"] as? Bool ?? false

            case "health":
                // What the trim pass found, and did not find. The one message
                // here that is about the app rather than about the page.
                if let reading = Health(message: body) {
                    surface.note(health: reading)
                }

            case "typing":
                // Somebody is halfway through a message. The session decides
                // what that is worth, and caps it.
                let typing = body["on"] as? Bool ?? false
                state.isTyping = typing
                // Only the page on the glass can be being typed in, and only
                // that one may hold the end of the day back for a sentence.
                if isLive { session.setTyping(typing) }

            case "sheet":
                // Something modal is covering the foot of the glass. The row
                // steps aside until it goes; see `quietBar` in BrowserScreen.
                state.isSheetUp = body["up"] as? Bool ?? false

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

/// Holds the pane weakly, because `WKUserContentController` holds its message
/// handlers strongly and the pane owns the web view's lifetime.
private final class ScriptRelay: NSObject, WKScriptMessageHandler {
    private weak var pane: InstagramWebView.WebPane?

    init(_ pane: InstagramWebView.WebPane) {
        self.pane = pane
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated {
            pane?.receive(message)
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
