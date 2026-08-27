import UIKit
import WebKit

/// The three pages of Instagram's the app keeps open at once.
///
/// Quiet used to be one web view with five entries pointing at it, and a tap on
/// **messages** was a tap on Instagram's own hidden navigation: the client
/// changed the address without loading anything, which kept the shell and the
/// caches. It did not keep the *feed*. Instagram's router unmounts the page you
/// left and builds it again when you come back — a spinner, the stories fetched
/// a second time, and the eight posts you had already read to scroll past
/// again. That is the site's behaviour, and nothing done from outside a single
/// page can talk it out of it.
///
/// So there is now one page per entry. The one on the glass is the one you are
/// reading; the other two are still there, still loaded, holding their own
/// scroll position and their own half-written message, and coming back to one
/// costs a `isHidden` and nothing else. It is what a tab bar has always meant
/// and what this row only looked like.
///
/// Three, not five. The clock and the search are Quiet's own screens and have
/// no page behind them.
///
/// What it costs is honest and worth writing down: two or three copies of
/// Instagram in one app's memory. iOS answers that by killing the web content
/// process of whichever it likes, without asking — so every pane writes down
/// where it was at the moment it leaves the glass, and a pane that comes back
/// from the dead comes back where it was. See `ThePlace` and `PaneStack.trim`.
enum Pane: String, CaseIterable, Sendable {
    case home, messages, profile

    /// Where a pane starts, when there is no place to put it back to.
    ///
    /// The profile has no address until the app knows whose profile it is,
    /// which is a fact the page has to be asked for. Until then there is no
    /// profile pane — see `WebSurface.goToMyProfile`, which falls back to the
    /// old behaviour rather than opening an empty one.
    func opening(me: String?) -> URL? {
        switch self {
        case .home: return ContentRules.home
        case .messages: return ContentRules.messages
        case .profile: return me.flatMap(ContentRules.profile(forHandle:))
        }
    }
}

/// The view the panes stand in, which does one thing: keep them the size of
/// itself.
///
/// Auto-resizing masks would very nearly do, and "very nearly" is what put the
/// row seven points up the screen once already. A frame set in `layoutSubviews`
/// is the same arithmetic every pass, including the first one, including the
/// pass after a rotation, and including the pane added three taps from now that
/// was not there when the container was laid out.
final class PaneContainer: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        for view in subviews where view.frame != bounds {
            view.frame = bounds
        }
    }
}

/// The panes, and which of them is on the glass.
///
/// SwiftUI's coordinator, so its life is the browsing screen's life. Everything
/// the rest of the app says to a web view still goes through the one
/// `WebSurface` — the surface simply points at whichever pane is in front, and
/// this is what moves that pointer.
@MainActor
final class PaneStack {
    let container = PaneContainer()

    private let surface: WebSurface

    /// Handed down to every pane, and replaced on every pass SwiftUI makes, for
    /// the same reason the single coordinator took it: the session is a value
    /// the view was built with and the delegates report to it.
    var session: QuietSession {
        didSet { panes.values.forEach { $0.session = session } }
    }

    private(set) var current: Pane = .home
    private var panes: [Pane: InstagramWebView.Coordinator] = [:]

    /// How tall the status bar is, once anybody knows, and what the page is
    /// asked to keep clear of. Both are the browsing screen's arithmetic and
    /// both have to reach a pane built long after that arithmetic settled.
    private(set) var top: CGFloat = 0
    private(set) var inset: UIEdgeInsets = .zero

    private var watchingMemory: NSObjectProtocol?

    init(session: QuietSession, surface: WebSurface) {
        self.session = session
        self.surface = surface
        surface.attach(self)

        // iOS asks once, politely, before it starts killing things itself.
        //
        // Answering is the difference between the app choosing which page it
        // loses and WebKit choosing — and WebKit has no idea which of the three
        // somebody is reading. Everything but the pane on the glass goes, after
        // each has written down where it was, so what a warning costs is a
        // reload the next time that entry is tapped rather than a page vanishing
        // out from under a thumb.
        watchingMemory = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.trim() }
        }
    }

    // MARK: - Coming and going

    /// Put a pane on the glass.
    ///
    /// The one being left is not torn down and not reloaded. It is hidden, its
    /// media is stopped, and its place is written down — and that is the whole
    /// of what a tab switch costs now.
    func show(_ pane: Pane) {
        guard pane != current || panes[pane] == nil else { return }

        if let leaving = panes[current] {
            // Written down on the way out rather than only when the app leaves
            // the screen. A pane iOS discards while it is off the glass has
            // nothing left to ask by the time anybody notices; this is the last
            // moment it is certain to be there.
            leaving.keepThePlace()
            // A reel does not go quiet by being hidden. WebKit stops drawing a
            // hidden layer and goes on playing the sound behind it, which is an
            // app talking from a page nobody is looking at.
            leaving.webView.pauseAllMediaPlayback()
            leaving.webView.isHidden = true
            leaving.letGoOfTheKeyboard()
        }

        current = pane
        let arriving = coordinator(for: pane)
        arriving.webView.isHidden = false
        container.bringSubviewToFront(arriving.webView)
        // The surface says what the page on the glass is doing, so it has to be
        // told what *this* page is doing — including that it finished loading
        // two minutes ago, which is what keeps the cover from coming back down
        // over a page that is ready.
        arriving.takeTheGlass()
        arriving.keepPullAlive(arriving.webView.scrollView)
    }

    /// The pane, built the first time it is asked for.
    ///
    /// Lazily, because an app that opened three copies of Instagram at launch
    /// would spend a cold start fetching two pages nobody has asked to see.
    private func coordinator(for pane: Pane) -> InstagramWebView.Coordinator {
        if let existing = panes[pane] { return existing }
        let made = InstagramWebView.Coordinator(
            session: session,
            surface: surface,
            stack: self,
            pane: pane,
            top: top,
            inset: inset
        )
        panes[pane] = made
        container.addSubview(made.webView)
        made.webView.frame = container.bounds
        made.webView.isHidden = pane != current
        made.openTheFirstPage()
        return made
    }

    /// Whether this pane is the one being read, which is what every delegate
    /// callback checks before it says anything about the page.
    ///
    /// A pane off the glass goes on living: Instagram polls, the client moves
    /// the address, the trim pass reports what it found. None of that is news
    /// about the screen, and a background pane allowed to speak would collapse
    /// the row, change the colour behind the clock, or put the "nothing
    /// arrived" screen over a page that is perfectly fine.
    func isLive(_ pane: Pane) -> Bool { pane == current }

    // MARK: - What the browsing screen hands down

    func hand(top: CGFloat, inset: UIEdgeInsets) {
        let movedTop = self.top != top
        self.top = top
        self.inset = inset
        for coordinator in panes.values {
            coordinator.apply(inset: inset)
            guard movedTop else { continue }
            coordinator.top = top
            coordinator.tellEveryPage(coordinator.webView, top: top)
            coordinator.tellThisPage(coordinator.webView)
        }
    }

    // MARK: - Putting them away

    /// Ask the pane in front for its page again.
    ///
    /// Everything the rest of the app calls `reload` for — the pull at the top,
    /// the **Try again** on the screen that says nothing arrived — is about the
    /// page somebody is looking at. The other two are not it.
    func reloadWhatIsInFront() {
        panes[current]?.startAgain()
    }

    /// Every pane, because the app is leaving the screen and any of the three
    /// may be the one iOS decides to discard.
    func keepThePlace() {
        panes.values.forEach { $0.keepThePlace() }
    }

    /// Everything but the one being read.
    ///
    /// Called on a memory warning, and by the pane that just lost its own web
    /// content process — the second is the same situation arriving a moment
    /// later and without the warning.
    func trim() {
        for (pane, coordinator) in panes where pane != current {
            coordinator.keepThePlace()
            drop(pane, coordinator)
        }
    }

    /// A pane whose web content process iOS killed.
    ///
    /// The one on the glass is asked for again, because there is a person
    /// looking at a blank rectangle. The others are simply dropped: their place
    /// was written down when they were left, so the next tap builds the pane
    /// back where it was, and rebuilding now would be fetching a page for
    /// somebody who is reading a different one.
    func died(_ pane: Pane) {
        guard let coordinator = panes[pane] else { return }
        guard pane != current else {
            coordinator.startAgain()
            return
        }
        // On the next turn, not this one. This arrives from a delegate call on
        // the coordinator being dropped, and dropping it is releasing the last
        // strong reference to the object whose method is running.
        Task { @MainActor [weak self] in
            guard let self, let coordinator = self.panes[pane], pane != self.current else { return }
            self.drop(pane, coordinator)
        }
    }

    private func drop(_ pane: Pane, _ coordinator: InstagramWebView.Coordinator) {
        coordinator.dismantle()
        coordinator.webView.removeFromSuperview()
        panes[pane] = nil
    }

    /// The profile pane, thrown away because it is no longer this reader's
    /// profile.
    ///
    /// Its place goes too. A page put back from twenty minutes ago would be the
    /// account somebody has just left, restored without a load and therefore
    /// without anything ever asking whether it was still theirs.
    func forgetTheProfile() {
        ThePlace.forget(.profile)
        guard let coordinator = panes[.profile] else { return }
        if current == .profile {
            // On the glass, so it cannot simply vanish. It is sent to the page
            // the new name owns instead.
            coordinator.openTheFirstPage()
        } else {
            drop(.profile, coordinator)
        }
    }

    /// Signing out, which is the one thing that has to reach all three.
    ///
    /// A pane left standing would be somebody else's inbox behind a fresh login
    /// screen. Every one of them goes, the home pane is built again from
    /// nothing, and what comes back is the login form.
    func startOver() {
        for (pane, coordinator) in panes {
            drop(pane, coordinator)
        }
        current = .home
        // Through `show` rather than by building one, so the surface is pointed
        // at the new web view and told what it is doing. Built by hand, the app
        // would go on holding a handle to the page it just threw away — and the
        // cover would stay up over a login form, because nothing would ever
        // have said the page underneath had finished.
        show(.home)
    }

    /// The browsing screen is going away — the curtain came down, or the app is
    /// being taken apart. Write all three places down before anything is
    /// released, so that coming back is coming back rather than starting over.
    func dismantle() {
        keepThePlace()
        for (pane, coordinator) in panes {
            drop(pane, coordinator)
        }
        // Here rather than in a `deinit`: this object belongs to the main actor
        // and a deinitialiser does not, which makes reaching a stored property
        // from one a fight with the compiler over a teardown SwiftUI already
        // calls reliably.
        if let watchingMemory {
            NotificationCenter.default.removeObserver(watchingMemory)
            self.watchingMemory = nil
        }
    }
}
