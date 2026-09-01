import SwiftUI
import UIKit

/// Instagram, full screen, with nothing of Quiet's drawn on top of it.
///
/// The app deliberately has no toolbar. A back button, an address bar or a
/// visible countdown would all be Quiet talking over the thing you opened it to
/// read — and a countdown in particular turns every minute into something to
/// watch. What time is left is in the panel, for the moments you actually want
/// to know.
///
/// Quiet carries the whole navigation now: home, search, messages, profile, and
/// a clock for its own settings. Five entries in a bar along the bottom, always
/// in the same place, on every page — including the ones where Instagram draws
/// no bar at all.
///
/// Four of them, for the first ten seconds. The clock is the only thing in the
/// row that is Quiet's, and an app that puts itself in the middle of somebody
/// else's navigation on the first frame is an app announcing itself before the
/// page it stands in front of has drawn a post. So it arrives late, in its own
/// slot, with a small plop; a double tap sends it away again and a tap on the
/// empty slot brings it back. See `isClockOnTheRow` and `clockButton`.
///
/// The bar is the shape Instagram's own is: the full width of the glass, flush
/// against the bottom edge, opaque, with a hairline above it and the system's
/// strip beneath. It was a floating pill for a while, and a pill is the one
/// thing on the screen that could never be mistaken for the app it stands in
/// front of. It does not shrink, fade or slide away while the page moves,
/// because Instagram's does not: a bar that answers the scroll is a bar you
/// end up watching.
///
/// It marks where you are, the way Instagram's does: the symbol you are
/// standing on is filled and the rest are outlines. Nothing else — no capsule,
/// no tint. That mark is most of what makes a row of icons feel like a place
/// rather than a toolbar.
///
/// Two places have no bar at all, for the same reason Instagram has none there:
/// a story and an open conversation both put something of their own along the
/// bottom edge, and a row drawn over the top of it covers the one control the
/// screen exists for. See `isImmersive`.
///
/// The three that are Instagram's are three pages, open at once. Tapping one is
/// not a navigation: the page is already there, already scrolled where it was
/// left, with the half-written message still in the box. It used to be one page
/// and five entries pointing at it, and coming back from the inbox meant
/// Instagram building the feed again — its router unmounts what you left, which
/// is the site's behaviour and not something an app outside a single page can
/// talk it out of. See `Pane` and `PaneStack`.
///
/// The two screens that are Quiet's own — the settings behind the clock, and
/// finding someone — are pages here rather than sheets over the top. A sheet
/// takes the whole screen and the row with it, so the app it belongs to
/// disappears for as long as it is up; a page leaves the row exactly where it
/// was, marks which of the five you are standing on, and is left the same way
/// everything else is: by tapping somewhere else.
///
/// The two Quiet needed lived inside Instagram's bar for a while, which is
/// where they belonged and where they twice failed to appear: a row built by
/// somebody else, out of generated class names, with no room for a fourth
/// child. Two silent failures is the argument settled. Instagram's row is taken
/// out — after the signed-in name has been read from it, which is the one thing
/// only that row knows.
///
/// The top stays Instagram's, and so does every pixel of the glass. A title row
/// of Quiet's own was tried for exactly one build and was wrong on sight.
///
/// So the page gets all of it, and starts itself below the clock. See
/// `InstagramWebView` and trim.css.
@MainActor
struct BrowserScreen: View {
    let session: QuietSession
    let surface: WebSurface
    let preferences: Preferences

    /// What the system has reserved at either end of the screen.
    ///
    /// Asked of the window at the moment the screen is built rather than
    /// defaulted and corrected, because a wrong first answer would draw the row
    /// over the home indicator for a frame. Asked again on appear, for the case
    /// where the window has laid nothing out yet and answers zero.
    @State private var topInset: CGFloat = SafeArea.top
    @State private var bottomInset: CGFloat = SafeArea.bottom

    /// The whole glass, in points.
    ///
    /// The web view is given this as a frame outright rather than being left to
    /// fill a stack that has been told to ignore the safe area. Twice now a
    /// photograph has shown the page stopping thirty-four points short of the
    /// bottom — the home indicator, to the point. Ignoring the safe area is a
    /// request. A size is not.
    @State private var glass: CGSize = SafeArea.glass
#if DEBUG
    @State private var whereTheGlassIs: CGFloat = -1
#endif

    /// Whether the clock is on the row at all.
    ///
    /// It is not there when the app opens. The four entries beside it are
    /// Instagram's and they are what somebody came here to use; the clock is
    /// Quiet's, and Quiet arriving first — in the middle of the row, on the
    /// first frame — is the app introducing itself before the thing it stands
    /// in front of has drawn a single post. So the row opens as four, and the
    /// fifth arrives ten seconds later, once the page is there and being read.
    ///
    /// The slot is held either way. Only the glyph comes and goes, so the four
    /// never move and a thumb aimed at messages finds messages whether the
    /// clock is out or not.
    @State private var isClockOnTheRow = false

    /// Whether the person has had a hand in that, which ends the ten seconds'
    /// say in it.
    ///
    /// Without this, a clock dismissed at the eighth second would come back at
    /// the tenth — the app overruling somebody about the one thing on the row
    /// they are allowed to overrule. Once a tap has said where the clock should
    /// be, the timer has no more opinions for the rest of the session.
    @State private var clockDecidedByHand = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            Paper.ground

            // The page's world: the glass, less the clock — and less the row
            // as well, but only where the row is opaque.
            InstagramWebView(
                surface: surface,
                session: session,
                // What the page is asked to keep clear of, which is the part of
                // the row it is allowed to run underneath. Nothing under a bar,
                // because the page stops above one; the whole row under an
                // island, so the scroll indicator does not run beneath the pill
                // and the last post can be scrolled out from behind it.
                inset: UIEdgeInsets(
                    top: 0,
                    left: 0,
                    bottom: furniture - pageGivesUp,
                    right: 0
                )
            )
            // Six mechanisms went into keeping Instagram's own bars off the
            // status bar: a content inset, a padding on the document, a lift on
            // whatever the page had pinned, and three attempts at finding that
            // element. Each of them worked on the feed and each of them left
            // the inbox with its search field cut in half, and the photograph
            // finally says why: that field is not pinned and not in the flow.
            // It is positioned against the *viewport*, which is what a chat
            // layout does — and a padding on the document cannot move it, and a
            // rule for sticky elements never sees it.
            //
            // So the viewport itself is made smaller at the top. Everything in
            // it is right by construction: what is fixed, what is sticky, what
            // is absolute, and what asks for a hundred per cent of the height.
            // There is nothing left to find and nothing left to lift.
            //
            // The same medicine was applied at the bottom, and it is the
            // twelfth answer to the sheet — the first that is not a mechanism.
            // Eleven were, and they shared a shape: each of them moved
            // something of Instagram's, and each had to recognise the thing it
            // was moving first. Recognition is the half that failed, in both
            // directions: it missed the account switcher for eight rounds
            // because Instagram never says a sheet is one, and then it took the
            // inbox's list of conversations for a sheet and moved that instead.
            // A sheet is anchored to the bottom of the viewport, so putting the
            // row outside the viewport lands every sheet above it, with nothing
            // of Instagram's touched, recognised or named.
            //
            // It is applied to one of the two shapes, and which one is not a
            // compromise — it is what the shapes *are*. See `pageGivesUp`.
            .frame(
                width: glass.width > 0 ? glass.width : nil,
                height: glass.height > 0 ? glass.height - topInset - pageGivesUp : nil
            )
            .padding(.top, topInset)

            if isCovered {
                cover
            }

            // Nothing arrived. Over the page, under the row: the five entries
            // still work, so somebody who cannot reach the feed can still open
            // the panel and see how much of the day is left.
            if let stumble = surface.stumble {
                StumbleView(kind: stumble) { surface.reload() }
                    .padding(.top, topInset)
                    .padding(.bottom, furniture)
                    .transition(.opacity)
            }

            // The strip behind the clock belongs to the app.
            //
            // Whatever the page does with its header, nothing of anybody's is
            // ever drawn across the time and the battery, because the app owns
            // those pixels. If the lift works the header sits just below this;
            // if it does not, the header slides underneath and out of sight.
            // Neither is broken.
            VStack(spacing: 0) {
                clockBand
                    .frame(height: topInset)
                Spacer(minLength: 0)
            }

            // Quiet's own two screens, as pages rather than as sheets, so that
            // the row along the bottom stays where it is and goes on saying
            // which of the five you are standing on.
            quietPages

            // Over the cover, so it is there from the first frame rather than
            // arriving with the page.
            quietBar

            statusBarStrip

            overlays
                .padding(.top, topInset + 8)
        }
        // The glass, said outright, for the same reason the web view is given a
        // size rather than told to fill something.
        //
        // The row moved seven points up the moment the web view stopped being
        // as tall as the screen — measured, on the run that shipped it: the
        // source said twenty-five and the photograph said thirty-two. Seven is
        // exactly what the web view's own box lost against the safe area, which
        // is the tell: with no child left the height of the glass, the stack
        // worked its own height out from its tallest child and came up short at
        // the bottom, and the row and the strip went up with it.
        //
        // Ignoring the safe area is a request about edges. It says nothing
        // about how tall the thing asking is. So the stack is given the glass,
        // and everything in it stands on the bottom of the screen because the
        // bottom of the screen is where the stack ends.
        .frame(
            width: glass.width > 0 ? glass.width : nil,
            height: glass.height > 0 ? glass.height : nil,
            alignment: .top
        )
        .ignoresSafeArea()
#if DEBUG
        // Where the whole browsing screen is, which is the question five
        // rounds of changes *inside* it never asked. A screen that is being
        // moved whole cannot be fixed from within, and telling those two apart
        // is one number.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { whereTheGlassIs = proxy.frame(in: .global).minY }
                    .onChange(of: proxy.frame(in: .global).minY) { whereTheGlassIs = $1 }
            }
        )
#endif
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: surface.hasLoaded)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: surface.isBare)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: surface.stumble)
        // The band changing colour: the first answer from a page, and every
        // change of scheme after it. A fade, because a flat area of the screen
        // changing colour in one frame reads as a glitch.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: surface.chrome)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: session.isPanelShowing)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: session.isSearchShowing)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: preferences.row)
        // The row leaving for a story and coming back from one, and the mark
        // moving from one entry to the next. Both are the address changing.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: surface.address)
        .onAppear {
            topInset = SafeArea.top
            bottomInset = SafeArea.bottom
            glass = SafeArea.glass
        }
        .task { await letTheClockArrive() }
#if DEBUG
        .task { await sayWhatTheGlassIs() }
#endif
    }

#if DEBUG
    /// The numbers this screen is actually laid out against, said aloud once,
    /// in the one staged scene that puts a keyboard up.
    ///
    /// `SafeArea.top` being right is not the same as `topInset` being right.
    /// The second is a copy taken at `onAppear`, and if the window had not been
    /// laid out by then it is the fallback rather than the notch — which would
    /// collapse the strip the clock stands in, and would also leave `glass` at
    /// zero, which takes the fixed height off the stack that holds everything
    /// else up. Two hypotheses, one line, and no more guessing at arithmetic.
    private func sayWhatTheGlassIs() async {
        guard Rehearsal.measuresTheSearchPage else { return }
        try? await Task.sleep(for: .seconds(2))
        NSLog(
            "Quiet: top %.1f held; glass %.0f x %.0f at %.1f, keyboard %@",
            Double(topInset), Double(glass.width), Double(glass.height),
            Double(whereTheGlassIs), Rehearsal.opensKeyboard ? "up" : "down"
        )
    }
#endif

    // MARK: - The clock arriving

    /// Ten seconds, and then the clock is on the row.
    ///
    /// Cancelled with the screen, and silent if a tap has already settled the
    /// question — either way round: somebody who asked for the clock at the
    /// third second is not shown it arriving again at the tenth, and somebody
    /// who sent it away is not handed it back.
    private func letTheClockArrive() async {
        guard !clockDecidedByHand, !isClockOnTheRow else { return }
        try? await Task.sleep(for: .seconds(Self.clockArrivesAfter))
        guard !Task.isCancelled, !clockDecidedByHand else { return }
        withAnimation(plop) { isClockOnTheRow = true }
    }

    /// How long the row stands as four.
    ///
    /// Long enough that the clock is not part of the app opening — which is the
    /// whole point of the wait — and short enough that it is there before
    /// anybody has finished the first screenful and gone looking for it.
    private static let clockArrivesAfter: TimeInterval = 10

    /// The plop.
    ///
    /// A spring rather than a fade, because the clock is arriving rather than
    /// being switched on, and a thing that arrives has a little weight to it:
    /// it comes up from just under full size, overshoots by a hair, and
    /// settles. About a quarter of a second, all of it inside a twenty-five
    /// point box — small enough that it registers out of the corner of an eye
    /// and never asks to be watched, which is the whole brief for anything this
    /// app draws.
    ///
    /// Reduce Motion gets the fade instead. Something appearing in the
    /// furniture still has to be noticed; it is the springing about that the
    /// setting is asking not to see.
    private var plop: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.28, dampingFraction: 0.58)
    }

    /// Whether Quiet's own blank is over the top of the web view.
    ///
    /// Two conditions, because there are two ways to have nothing on the
    /// glass. Until the first navigation settles there is no page at all. And
    /// after it settles there is often still nothing to look at: Instagram is
    /// a shell, and the second or two between the request finishing and the
    /// first screen appearing is its own black rectangle. Both are the app
    /// starting, and both should look like it. See `WebSurface.isBare`.
    private var isCovered: Bool {
        !surface.hasLoaded || surface.isBare
    }

    /// What Quiet holds over the web view until there is a page under it.
    ///
    /// **The colour is the band's.** It was the app's own ground for as long
    /// as the cover was only ever up before the first frame, and against a
    /// sampled band that is a second dark on the same screen: the photograph
    /// that started this shows a grey strip across the top and a black void
    /// under it, with the seam between them the most visible thing on the
    /// glass. One colour, top to bottom — whatever the clock is standing on is
    /// what the whole screen is — so a cold start reads as one surface waiting
    /// rather than as two surfaces disagreeing. When the page arrives it is one
    /// colour fading to another, which is what the band already does.
    ///
    /// **And it says whose blank it is.** Small, low-contrast, in the middle:
    /// enough to answer "is this thing broken" and not enough to be a splash
    /// screen. The line is the app's name and the promise under it, and it is
    /// the same line in every language — it is a wordmark, not a sentence, so
    /// it is `verbatim` rather than something the catalogue would ask German
    /// for.
    private var cover: some View {
        ZStack {
            clockBand
            Text(verbatim: "Quiet: No More Doomscrolling")
                .font(.quietSmall)
                .foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    // MARK: - Quiet's own pages

    /// The settings behind the clock, and finding someone.
    ///
    /// Opaque, from the bottom of the clock to the top of the row, so the page
    /// underneath is neither visible nor scrollable while one of them is up.
    /// They replace each other rather than stacking: the row is the way between
    /// them, and a stack of two would leave a screen behind whichever one you
    /// left.
    @ViewBuilder
    private var quietPages: some View {
        if isShowingQuietPage {
            // `.top`, and it is the whole of the bug the photograph showed.
            //
            // Measured, as a pair, which is what finally settled it. The page
            // with no keyboard up starts at 62 — the strip the clock stands in
            // — and the field 54 below that. With a keyboard the page starts at
            // **minus 79.5** and the field 116 below *that*: the column moved
            // up a hundred and forty-one points, and inside it the navigation
            // bar put back the sixty-two it now believed it owed the status
            // bar, having found itself at the top of the window.
            //
            // A hundred and forty-one is half of two hundred and eighty-three,
            // and two hundred and eighty-three is what a keyboard is on this
            // phone. That is the shape of an overflow being *centred*: the
            // column asks for the glass plus a keyboard, gets the glass, and a
            // stack with no alignment puts the difference out of both ends —
            // half of it above the top of the screen, taking the clock's strip
            // and the page's own title row onto the time.
            //
            // The stack this one stands in has said `.top` since it was
            // written, for a related reason. This one never did, and the
            // default is centre. Told which end to lose, the overflow goes
            // downward instead, behind the keyboard, where there is nothing to
            // read.
            ZStack(alignment: .top) {
                Paper.page
                VStack(spacing: 0) {
                    // The clock's own strip, which the app already draws.
                    Color.clear.frame(height: topInset)

                    if session.isPanelShowing {
                        PanelView(
                            session: session,
                            surface: surface,
                            preferences: preferences,
                            onFindSomeone: {
                                session.isPanelShowing = false
                                session.isSearchShowing = true
                            },
                            onDismiss: { session.isPanelShowing = false }
                        )
                    } else {
                        SearchView(
                            surface: surface,
                            onDone: { session.isSearchShowing = false },
                            onOpen: { url in
                                surface.visit(url)
                                session.isSearchShowing = false
                            }
                        )
                    }

                    // Clear of the row, which is drawn over the top of this.
                    Color.clear.frame(height: furniture)
                }
            }
            // Deliberately no size here, for now. One was added when the
            // page was found at minus seventy-nine with a keyboard up, on the
            // reasoning that a stack with no size takes the one its content
            // asks for and an overflowing column is centred. The next run read
            // minus seventy-nine again, to the tenth of a point, so whatever
            // moves this page it is not that — and a change that fixed nothing
            // is taken back rather than left in to be inherited as a fact.
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    private var isShowingQuietPage: Bool {
        session.isPanelShowing || session.isSearchShowing
    }

    // MARK: - The row

    /// Where the row says you are.
    ///
    /// Instagram's row fills the symbol you are standing on and outlines the
    /// rest, and that mark is most of what makes a row of icons feel like a
    /// place rather than a toolbar. Quiet's says the same thing about the two
    /// screens that are its own.
    private enum Entry: Hashable {
        case home, search, clock, messages, profile
    }

    /// Which of Instagram's three you are standing in.
    ///
    /// The pane, now, rather than the address. Three pages are open at once and
    /// each keeps its own place, so "where you are" is which of them is on the
    /// glass — and that is also what a tab bar has always marked. Tap a friend
    /// in the feed and you are still standing in **home**, the way you are
    /// still standing in a tab on every phone ever made; the address said
    /// otherwise, and had to, because with one page there was nothing else to
    /// ask.
    private var pageEntry: Entry {
        switch surface.pane {
        case .home: return .home
        case .messages: return .messages
        case .profile: return .profile
        }
    }

    private var current: Entry {
        if session.isPanelShowing { return .clock }
        if session.isSearchShowing { return .search }
        return pageEntry
    }

    /// The pages that own the bottom edge, where Instagram draws no bar either.
    ///
    /// A story has its reply field down there and a conversation has its
    /// message box, and both are the reason the screen is open. A row of five
    /// drawn across them is the app covering the one control that matters,
    /// which is exactly what a photograph of a story showed.
    ///
    /// Never while one of Quiet's own pages is up: the row is the way out of
    /// those, and a way out that is not on the screen is not a way out.
    private var isImmersive: Bool {
        guard !isShowingQuietPage else { return false }
        return ContentRules.isImmersive(surface.address)
    }

    /// The row, along the bottom edge, in the shape Instagram's own is.
    ///
    /// Full width, flush, opaque, with a hairline above it and the system's own
    /// strip beneath — which is a bar rather than a piece of the app's
    /// furniture floating over somebody else's page. There is no second shape
    /// for phones with a home button: those reserve nothing at the bottom, so
    /// the same bar simply meets the edge of the glass.
    @ViewBuilder
    private var quietBar: some View {
        if !isImmersive {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                switch preferences.row {
                case .bar: flushBar
                case .island: island
                }
            }
            // Out of the way while Instagram has a sheet up, and back the
            // moment it goes.
            //
            // The row is the one part of the screen that is always in the same
            // place, and taking it away was argued against on exactly those
            // grounds once. The photograph settles it the other way: a sheet
            // covers the foot of the glass, the pill floats over the foot of
            // the glass, and "Log in to an Existing Account" was drawn through
            // the middle of it. A button nobody can see is a button nobody can
            // press. A sheet is also the one thing you can be doing that has
            // nowhere else to go — so for as long as it is up, it is the
            // screen, and the furniture stands down.
            //
            // Faded rather than removed, and inert while faded, so nothing
            // takes a tap meant for the sheet underneath it.
            .opacity(isRowLive ? 1 : 0)
            .allowsHitTesting(isRowLive)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.18),
                value: isRowLive
            )
            .transition(.opacity)
        }
    }

    /// Whether the row is answering for itself at all.
    ///
    /// It stands down for two things, and both are the same thing said twice:
    /// while it would be *over* what you are doing rather than beside it.
    ///
    /// A sheet covers the foot of the glass. So does a keyboard — every box you
    /// write into on Instagram is pinned to the bottom of the page, which is
    /// exactly where a floating row is, and a send button under a pill is a
    /// send button nobody can press. Comments, messages, search: all of them.
    /// It is also what every tab bar on this phone does, and the hand already
    /// expects it.
    ///
    /// Live regardless the moment one of Quiet's own pages is up: the row is
    /// the way out of those, and a sheet left open on the page behind them is
    /// no reason to take the way out away.
    private var isRowLive: Bool {
        if isShowingQuietPage { return true }
        return !surface.isSheetUp && !surface.isTyping
    }

    /// Instagram's own: the full width of the glass, flush against the bottom
    /// edge, opaque, a hairline above it, the system's strip beneath.
    private var flushBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 0.5)
            row
                .frame(height: Self.barHeight)
            // The system's strip, in the bar's own colour, the way every bar on
            // a phone with a home indicator ends.
            Color.clear
                .frame(height: bottomInset)
        }
        .background(Paper.ground)
    }

    /// The other one: a pill, inset from both edges, with the page running
    /// underneath it.
    ///
    /// It draws itself in while the page moves away under your thumb and comes
    /// back out the moment it stops. It never leaves — a control that
    /// disappears is a control you end up hunting for — and it never shrinks on
    /// the bar, because a bar standing on the bottom edge has nothing to float
    /// over and nothing to get out of the way of.
    private var island: some View {
        row
            .frame(height: Self.islandHeight)
            .padding(.horizontal, 6)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
            .padding(.horizontal, 22)
            .scaleEffect(surface.isBarCollapsed ? 0.86 : 1, anchor: .bottom)
            .opacity(surface.isBarCollapsed ? 0.62 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86),
                value: surface.isBarCollapsed
            )
            // Off the bottom edge, with the app's own strip beneath it in the
            // page's colour, so what is under a row that floats still reads as
            // the page rather than as a black band.
            .padding(.bottom, Self.islandLift)
    }

    /// How much of the bottom of the screen the row stands on.
    ///
    /// Nothing here on a page that has no row.

    /// How much of that the *page* gives up, which is not the same number and
    /// depends on which shape the row is drawn in.
    ///
    /// **The bar gives up its own height.** It is opaque and the width of the
    /// glass, so a page running underneath it is a page nobody can see. The
    /// pixels cost nothing to hand over — and handing them over is what puts
    /// every sheet Instagram opens above the row instead of behind it, without
    /// anything of Instagram's being recognised or moved. Eleven mechanisms
    /// tried to do that by recognition and failed in both directions.
    ///
    /// **The island gives up nothing.** A pill that floats over a black band is
    /// not floating over anything: seeing the feed move underneath it, blurred
    /// through the material, is the entire reason to choose that shape rather
    /// than Instagram's own. Taking the page away beneath it turns the nicer
    /// object into a worse one, which was the first thing anybody said about
    /// it after a build.
    ///
    /// So the cost lands where the choice was made. Choose the island and a
    /// sheet reaches the bottom edge, which means Instagram's account switcher
    /// puts its last button under the pill; choose the bar and it never can.
    /// That is a real trade and it is stated here rather than hidden, because
    /// the alternative — recognising sheets — is the thing that took eleven
    /// builds to stop doing.
    private var pageGivesUp: CGFloat {
        guard !isImmersive else { return 0 }
        switch preferences.row {
        case .bar: return Self.barHeight + bottomInset
        case .island: return 0
        }
    }

    private var furniture: CGFloat {
        guard !isImmersive else { return 0 }
        switch preferences.row {
        case .bar: return Self.barHeight + bottomInset
        case .island: return Self.islandHeight + Self.islandLift + Self.islandAir
        }
    }

    /// The five entries, in Instagram's own order: home, search, the middle
    /// one, messages, you. The middle is where Instagram puts the thing its app
    /// does rather than the thing the site does, and Quiet's is the clock.
    ///
    /// Five slots, always. The clock's is empty until the clock is out, and an
    /// empty slot is still a slot: it holds its width, so the other four are
    /// where they were, and it still takes a tap, which is how the clock is
    /// asked back.
    private var row: some View {
        HStack(spacing: 0) {
            barButton(.home, "house", "house.fill", Text("Home"))
            barButton(.search, "magnifyingglass", "magnifyingglass", Text("Find someone"))
            clockButton
            barButton(.messages, "paperplane", "paperplane.fill", Text("Messages"))
            // Only once the page has said who is signed in. A button that leads
            // nowhere is worse than one that arrives a second late.
            if surface.me != nil {
                myProfileButton
            }
        }
    }

    /// The middle entry, which is the one thing in the row that answers a tap
    /// with something other than a page.
    ///
    /// Three things a finger can do here, and they are three because the clock
    /// is the only entry a person is allowed to have an opinion about being
    /// there at all:
    ///
    /// **Tap it when it is out** and the panel opens, which is what every other
    /// entry in the row does and what this one has always done.
    ///
    /// **Tap the empty slot** and it arrives — the same plop as the ten
    /// seconds, because it is the same arrival, asked for rather than waited
    /// out. The slot is live the whole time it is empty, so this is never a
    /// hunt: the clock is where the clock has always been.
    ///
    /// **Tap it twice and it goes away.** Sending it away is the point of the
    /// gesture and it is deliberately not a thing you can do by accident with
    /// one finger, which is why it is two taps rather than a press: a press is
    /// what a thumb resting on the row does by itself.
    ///
    /// The double tap is declared before the single one, which is how SwiftUI
    /// is told which of the two to try first; the single tap then waits out the
    /// double's window before it fires. That wait is the cost of the gesture
    /// and it is paid by the panel opening a moment after the tap rather than
    /// on it — worth it here, on one entry of five, and worth it nowhere else
    /// in the row, which is why the other four are plain buttons that answer
    /// instantly.
    private var clockButton: some View {
        let here = current == .clock
        return glyph(.clock, here, theClock(filled: false), theClock(filled: true))
            .foregroundStyle(Color(uiColor: .label))
            // The glyph, and only the glyph. The frame around it is the slot,
            // which stays whether or not there is anything drawn in it.
            .scaleEffect(scaleOfTheClock)
            .opacity(isClockOnTheRow ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { clockTappedTwice() }
            .onTapGesture { clockTapped() }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(here ? .isSelected : [])
            // A slot with nothing in it is not "Quiet settings" — it is the way
            // to get the clock back, and it says so. The number goes with the
            // clock: there is nothing there to be told the time by.
            .accessibilityLabel(isClockOnTheRow ? Text("Quiet settings") : Text("Show the clock"))
            .accessibilityValue(Text(isClockOnTheRow ? timeLeftAloud : ""))
            .accessibilityAction { clockTapped() }
            // Two taps in the same place is a sighted gesture. Sending the
            // clock away is not, so it is also a named action.
            .accessibilityAction(named: Text("Hide the clock")) { hideTheClock() }
    }

    /// Where the plop starts from.
    ///
    /// Not zero. A glyph that grows out of nothing is a thing being drawn; one
    /// that comes up from just under its own size is a thing arriving, and the
    /// difference at this scale is the whole character of it.
    private var scaleOfTheClock: CGFloat {
        if isClockOnTheRow { return 1 }
        return reduceMotion ? 1 : 0.45
    }

    private func clockTapped() {
        guard isClockOnTheRow else { return showTheClock() }
        go(to: .clock)
    }

    /// Two taps on an empty slot mean the same as one: whoever is tapping there
    /// wants the clock, and counting their taps back at them is not an answer.
    private func clockTappedTwice() {
        guard isClockOnTheRow else { return showTheClock() }
        hideTheClock()
    }

    private func showTheClock() {
        Touch.tick()
        clockDecidedByHand = true
        withAnimation(plop) { isClockOnTheRow = true }
    }

    private func hideTheClock() {
        Touch.tick()
        clockDecidedByHand = true
        withAnimation(plop) { isClockOnTheRow = false }
    }

    /// What the clock says to somebody who cannot see it.
    ///
    /// The number was reachable in exactly one way: open the panel, hear it,
    /// close the panel. For anybody reading the screen with a finger that is
    /// three deliberate moves and a modal to get back out of, to answer the
    /// question a sighted reader answers by looking at a row they were already
    /// looking at. The clock is the element that means "your time"; it should
    /// say what it means.
    ///
    /// A value rather than a longer label, because that is what VoiceOver reads
    /// second and what the rotor carries — "Quiet settings, twelve minutes left
    /// today, button" — and because a label that changed every minute would
    /// change what the button is called.
    ///
    /// **And it is not always said.** The app has a switch for whether it
    /// counts anybody down, and the reason it exists is that for some people a
    /// sentence saying five minutes remain is precisely what starts a last five
    /// minutes. A spoken value on the row is a countdown — more of one than the
    /// panel is, since it arrives on the way past rather than when asked — so it
    /// obeys the same switch. Turned off, the clock is a button called Quiet
    /// settings, and the number is still one tap away inside, for a reader who
    /// went looking for it.
    /// The middle entry, and the one place the day's end is visible without
    /// anybody going to look for it.
    ///
    /// The app refuses to show a countdown, and the refusal is right: a clock
    /// you can watch is a clock you do watch, and a number ticking down turns
    /// the last ten minutes into the loudest ten of the day. But there is a
    /// middle, and this is it — the glyph changes **once**, at five minutes, to
    /// an hourglass with the sand through it. No number, no ticking, and
    /// nothing that rewards looking twice: one state, and you already know.
    ///
    /// In the last five minutes it is the hourglass whether you are standing on
    /// this entry or not. The row's usual two states answer "where am I", and
    /// for those five minutes that is not the question.
    private func theClock(filled: Bool) -> String {
        if isNearlyOut { return "hourglass.bottomhalf.filled" }
        return filled ? "clock.fill" : "clock"
    }

    private var isNearlyOut: Bool {
        session.screen == .browsing && session.remaining <= Self.lastStretch
    }

    /// Five minutes — read off the first thing the app says out loud as the day
    /// runs out rather than written down again, so the glyph and the sentence
    /// can never be a minute apart. See `QuietSession.warnings`.
    private static let lastStretch = TimeInterval((QuietSession.warnings.max() ?? 5) * 60)

    private var timeLeftAloud: String {
        guard preferences.saysWhatIsLeft else { return "" }
        switch session.screen {
        case .spent: return String(localized: "No time left today.")
        default: return String(localized: "\(Phrase.remaining(session.remaining)) left today.")
        }
    }

    /// The colour of the band the clock stands on.
    ///
    /// The page's own colour, sampled from what Instagram actually draws along
    /// the top of itself, so there is no seam. The app owns these pixels — the
    /// page's viewport starts underneath them — but nothing about them should
    /// announce that. The clock stands on the page rather than on a shelf above
    /// it.
    ///
    /// It was one step off the page for a while, on the argument that a band
    /// wants an edge. In the dark that argument loses: the system's black
    /// against Instagram's near-black is a hard line across the top of every
    /// screen, and the grey that replaced it was a second line in a lighter
    /// colour. Asked for plainly, the answer was no line at all.
    ///
    /// Which colour that is stays Instagram's business rather than Quiet's. It
    /// is sampled rather than written down here, so it follows the phone from
    /// light to dark, the app from the feed to a story, and Instagram through a
    /// redesign, with nothing here touched. See `WebSurface.chrome`.
    private var clockBand: Color { surface.chrome ?? Self.groundBand }

    /// Until the page has answered, and for a page that has nothing to say.
    /// The colour the cover underneath is painted in — so the handover from
    /// Quiet's blank to Instagram's page is one colour changing, not a band
    /// appearing.
    private static let groundBand = Paper.ground

    /// The height every bar along the bottom of an iPhone has been since the
    /// first one, and the height of Instagram's.
    private static let barHeight: CGFloat = 49

    /// The island is a little taller than the bar, because it is a shape rather
    /// than an edge and needs the air.
    private static let islandHeight: CGFloat = 52

    /// How far it stands off the bottom edge.
    ///
    /// Twelve points to begin with, and twenty-five now: thirteen more, which is
    /// what two millimetres is on a phone at roughly a hundred and sixty points
    /// to the inch. It is the gap that was asked for and the gap that moves —
    /// the pill keeps the height it has always had, because a taller pill with
    /// the same air beneath it does not sit higher, it crowds the edge harder.
    ///
    /// It went to thirty-eight for a while, and that was a fourth guess at a
    /// number that had been right since the second. Twenty-five was being drawn
    /// at twelve and a half, and the cause was nowhere near here: a container
    /// added between the app and the window was centring the whole browsing
    /// screen and hanging it off the bottom of the glass by almost exactly the
    /// thirteen points this was moving by. Every time this number went up, the
    /// screen it stands on went down. See `RootView`.
    ///
    /// CI now measures the drawn gap against this number on every push, so a
    /// disagreement between the two is a red build rather than a photograph.
    private static let islandLift: CGFloat = 25

    /// And the air above it, before the page starts.
    private static let islandAir: CGFloat = 12

    /// The last entry, with your own face in it, the way Instagram's row ends.
    /// An outline of a person stands in until the page has handed one over.
    private var myProfileButton: some View {
        let here = current == .profile
        return Button { go(to: .profile) } label: {
            Group {
                if let face = surface.myFace {
                    Image(uiImage: face)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 25, height: 25)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                Color(uiColor: .label).opacity(here ? 0.95 : 0.2),
                                lineWidth: here ? 1.5 : 0.5
                            )
                        )
                } else {
                    Image(systemName: here ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color(uiColor: .label))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Your profile"))
        .accessibilityAddTraits(here ? .isSelected : [])
    }

    /// What a tap on the row does.
    ///
    /// Tapping the entry you are already standing on takes you to the top of
    /// it, rather than loading the page you are looking at all over again. Every
    /// tab bar on iOS has done this since there were tab bars, Instagram's
    /// included, and its absence is the kind of thing nobody reports and
    /// everybody feels.
    ///
    /// A tap on one of the three that are Instagram's also closes whichever of
    /// Quiet's own pages is up — and when the page underneath was already the
    /// one being asked for, closing it is the whole of the answer. Reloading
    /// the feed somebody was reading two seconds ago, because they looked at
    /// the clock, is the app losing their place for them.
    ///
    /// And every tap gives a tick under the thumb. Instagram's row does; a row
    /// that does not answer the finger reads as a picture of a row.
    private func go(to entry: Entry) {
        Touch.tick()

        switch entry {
        case .clock:
            session.isSearchShowing = false
            session.isPanelShowing = true

        case .search:
            session.isPanelShowing = false
            session.isSearchShowing = true

        case .home, .messages, .profile:
            let wasOverThePage = isShowingQuietPage
            session.isPanelShowing = false
            session.isSearchShowing = false

            guard pageEntry != entry else {
                if !wasOverThePage { surface.scrollToTop() }
                return
            }
            switch entry {
            case .home: surface.goToFeed()
            case .messages: surface.goToMessages()
            default: surface.goToMyProfile()
            }
        }
    }

    private func barButton(
        _ entry: Entry,
        _ outline: String,
        _ solid: String,
        _ label: Text
    ) -> some View {
        let here = current == entry
        return Button { go(to: entry) } label: {
            glyph(entry, here, outline, solid)
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(here ? .isSelected : [])
    }

    /// Instagram's own drawing where the page has handed one over, and Quiet's
    /// stand-in until it does.
    ///
    /// Side by side with the real row, SF Symbols are unmistakably somebody
    /// else's drawings — a different house, a differently tilted paper plane.
    /// Redrawing Instagram's by hand would be both worse and a liberty, so
    /// these are the actual glyphs, taken out of the row the app hides. See
    /// `sendIcons` in trim.js.
    ///
    /// The clock has no counterpart, because it is the one thing here that is
    /// Quiet's rather than Instagram's.
    @ViewBuilder
    private func glyph(_ entry: Entry, _ here: Bool, _ outline: String, _ solid: String) -> some View {
        if entry == .clock {
            // Quiet's own, and the only one in the row that is. It is drawn
            // rather than taken from a font so that it can be built to the same
            // specification as the four beside it: a twenty-five point box, a
            // two point stroke, round caps, and filled when you are standing on
            // it. An SF Symbol among Instagram's own icons is a lighter line
            // and a different geometry, and beside them it reads as the one
            // thing in the row that came from somewhere else — which is exactly
            // what a photograph of it showed.
            ClockGlyph(filled: here)
        } else if let name = Self.drawnByInstagram[entry], let icon = surface.icon(name, on: here) {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
        } else {
            Image(systemName: here ? solid : outline)
                .font(.system(size: 24, weight: here ? .semibold : .regular))
        }
    }

    private static let drawnByInstagram: [Entry: String] = [
        .home: "home", .search: "search", .messages: "messages"
    ]

    /// Transparent, and exactly as tall as the status bar, so it never sits over
    /// anything on the page that can be tapped. A tap does what a tap on the
    /// status bar has always done, and nothing else: there is no hidden gesture
    /// here any more.
    private var statusBarStrip: some View {
        Color.clear
            .frame(height: topInset)
            .contentShape(Rectangle())
            .onTapGesture { surface.scrollToTop() }
            .accessibilityHidden(true)
    }

    private var overlays: some View {
        VStack(spacing: 10) {
            if let notice = session.notice {
                NoticeView(notice: notice) { session.dismissNotice(token: $0) }
            }
            if !surface.missingResources.isEmpty {
                alarm("Quiet is missing \(surface.missingResources.joined(separator: " and ")). Reinstall from a clean build.")
            }
            if !session.isMemoryReliable {
                alarm("Quiet cannot save to this phone's keychain. Your limit will not survive closing the app.")
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: session.notice)
    }

    /// The only red in the app.
    ///
    /// Two things can go wrong quietly enough to leave Quiet looking healthy
    /// while doing the opposite of its job: the trim files missing from the
    /// bundle, which brings Reels back, and a keychain that refuses writes,
    /// which throws the limit away at every launch. Neither is allowed to be
    /// discovered by accident.
    private func alarm(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.quietSmall.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.red.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
    }
}

/// Quiet's mark: a clock, drawn to the same specification as the icons it
/// stands among.
///
/// Instagram's are twenty-five points across with a two point stroke and round
/// ends, and they fill solid when you are standing on them. So is this. The
/// hands are punched out of the filled disc rather than painted over it in the
/// background colour, so it is right on the bar and right on the island, where
/// what is behind it is a blur rather than a colour.
///
/// It is a clock because Quiet is a limit on time and a clock is the one
/// drawing everybody already reads as time. It is where Instagram puts Reels,
/// which is the trade the whole app is.
private struct ClockGlyph: View {
    let filled: Bool

    private static let side: CGFloat = 25
    private static let stroke: CGFloat = 2

    private var line: StrokeStyle {
        StrokeStyle(lineWidth: Self.stroke, lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        ZStack {
            if filled {
                Circle().fill(Color(uiColor: .label))
                Hands().stroke(Color.black, style: line).blendMode(.destinationOut)
            } else {
                Circle()
                    .strokeBorder(Color(uiColor: .label), lineWidth: Self.stroke)
                Hands().stroke(Color(uiColor: .label), style: line)
            }
        }
        .compositingGroup()
        .frame(width: Self.side, height: Self.side)
    }

    /// Ten past twelve, which is the arrangement every clock in every
    /// advertisement has used for a century, because it is the one that reads as
    /// a clock at any size.
    private struct Hands: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            path.move(to: CGPoint(x: centre.x, y: centre.y - rect.height * 0.25))
            path.addLine(to: centre)
            path.addLine(to: CGPoint(x: centre.x + rect.width * 0.19, y: centre.y))
            return path
        }
    }
}

/// The tick under the thumb.
///
/// One generator, kept alive and told to get ready, because an impact asked for
/// cold arrives late enough to feel like a different tap. Light, because this is
/// a row of five and not a decision.
@MainActor
enum Touch {
    private static let generator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()

    static func tick() {
        generator.impactOccurred(intensity: 0.7)
        generator.prepare()
    }
}

/// The height of the status bar.
///
/// Read from the window rather than from a `GeometryReader`, because the strip
/// above sits in a container that deliberately ignores the safe area, where a
/// proxy would report zero. Quiet is portrait-only, so this does not change
/// while the app is running.
@MainActor
enum SafeArea {
    static var top: CGFloat { insets?.top ?? 20 }
    static var bottom: CGFloat { insets?.bottom ?? 0 }

    /// The window's own size, which is the screen: Quiet has one window and no
    /// split view. Zero when there is no window yet, and a zero is read as "no
    /// opinion" rather than as a size, so nothing is squashed by an early
    /// answer.
    static var glass: CGSize { window?.bounds.size ?? .zero }

    private static var insets: UIEdgeInsets? { window?.safeAreaInsets }

    /// Quiet's own window, which is not always the key one.
    ///
    /// `isKeyWindow` is the obvious spelling, and it is wrong at exactly the
    /// moment this matters. While a keyboard is up, the window receiving keys
    /// is the keyboard's own: a full-screen window above the app's, with
    /// nothing above *it*, and therefore a top inset of zero. Read from there,
    /// the phone has no notch — the strip Quiet reserves for the clock
    /// collapses, and every page in the app moves up by the height of the
    /// status bar and sits under the time.
    ///
    /// Quiet has one window and it is at the ordinary level. Everything the
    /// system puts over that — the keyboard, the window an alert arrives in —
    /// sits above it by definition, which is what makes the level the honest
    /// question to ask rather than which window has the keys.
    private static var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let windows = scene?.windows else { return nil }
        return windows.first { $0.windowLevel == .normal && !$0.isHidden }
            // Both fallbacks are for a state that should not happen. The old
            // answer is kept as the first of them because a wrong inset beats
            // no inset: twenty points of guess is a worse screen, and nil is a
            // blank one.
            ?? windows.first { $0.isKeyWindow }
            ?? windows.first
    }

#if DEBUG
    /// Both answers, side by side, for the rehearsal that puts a keyboard up.
    ///
    /// The bug this file just fixed is invisible in a screenshot taken without
    /// one and invisible in a unit test, because it is a question about which
    /// of the system's windows is in front. So the app says what it read, and
    /// a run that puts a keyboard up says whether the two spellings still
    /// disagree.
    static var reading: String {
        let keyed = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return "top \(top) from ours, \(keyed.map { "\($0.safeAreaInsets.top)" } ?? "no window") from isKeyWindow"
    }
#endif
}
