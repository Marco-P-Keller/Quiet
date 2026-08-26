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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground)

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

            if !surface.hasLoaded {
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: surface.hasLoaded)
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
    }

    /// Quiet's own paper, held over the web view until the first page settles.
    /// A cold launch should look like the app deciding to start, not like a
    /// blank browser.
    private var cover: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
            .transition(.opacity)
            .accessibilityHidden(true)
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
            ZStack {
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
                                surface.open(url)
                                session.isSearchShowing = false
                            }
                        )
                    }

                    // Clear of the row, which is drawn over the top of this.
                    Color.clear.frame(height: furniture)
                }
            }
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

    /// Where the page is, whatever is drawn over the top of it.
    private var pageEntry: Entry {
        let path = surface.address?.path ?? "/"
        if path.hasPrefix("/direct") { return .messages }
        if let me = surface.me, path == "/\(me)" || path == "/\(me)/" { return .profile }
        return .home
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
    /// Live regardless the moment one of Quiet's own pages is up: the row is
    /// the way out of those, and a sheet left open on the page behind them is
    /// no reason to take the way out away.
    private var isRowLive: Bool {
        if isShowingQuietPage { return true }
        return !surface.isSheetUp
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
        .background(Color(uiColor: .systemBackground))
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
    private var row: some View {
        HStack(spacing: 0) {
            barButton(.home, "house", "house.fill", Text("Home"))
            barButton(.search, "magnifyingglass", "magnifyingglass", Text("Find someone"))
            barButton(.clock, "clock", "clock.fill", Text("Quiet settings"))
                .accessibilityValue(Text(timeLeftAloud))
            barButton(.messages, "paperplane", "paperplane.fill", Text("Messages"))
            // Only once the page has said who is signed in. A button that leads
            // nowhere is worse than one that arrives a second late.
            if surface.me != nil {
                myProfileButton
            }
        }
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
    private var clockBand: Color { surface.chrome ?? Self.systemBand }

    /// Until the page has answered, and for a page that has nothing to say.
    /// The system's own page colour, which is what the cover underneath is
    /// painted in — so the handover from Quiet's blank to Instagram's page is
    /// one colour changing, not a band appearing.
    private static let systemBand = Color(uiColor: .systemBackground)

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

    private static var window: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
