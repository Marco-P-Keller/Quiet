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
/// a clock for its own settings. Five entries in a floating pill, always in the
/// same place, on every page — including the ones where Instagram draws no bar
/// at all.
///
/// It marks where you are, the way Instagram's does: the symbol you are
/// standing on is filled, and a lighter capsule sits behind it. That mark is
/// most of what makes a row of icons feel like a place rather than a toolbar.
///
/// The pill draws itself in while the page moves away under your thumb and
/// comes back out when it stops. It never leaves, because a control that
/// disappears is a control you end up hunting for. It sits low, over the home
/// indicator, and the page runs on beneath it to the bottom edge — a row that
/// floats and a page that stops under it is the worst of both.
///
/// The two Quiet needed lived inside Instagram's bar for a while, which is
/// where they belonged and where they twice failed to appear: a row built by
/// somebody else, out of generated class names, with no room for a fourth
/// child. Two silent failures is the argument settled. Instagram's row is taken
/// out — after the signed-in name has been read from it, which is the one thing
/// only that row knows.
///
/// The top stays Instagram's, and so does every pixel of the glass. A title row
/// of Quiet's own was tried for exactly one build and was wrong on sight; the
/// opaque band behind the clock that replaced it was wrong for a subtler
/// reason, which took a photograph to see — whatever the app takes off the top
/// of the page comes back as a black strip along the bottom, above the row,
/// where Instagram runs its next photograph.
///
/// So the page gets all of it, and starts itself below the clock. See
/// `InstagramWebView` and trim.css.
///
/// The web view keeps the whole screen and is told which parts of it are spoken
/// for, so nothing of Quiet's ever covers the page.
@MainActor
struct BrowserScreen: View {
    let session: QuietSession
    let surface: WebSurface

    /// What the system has reserved at either end of the screen.
    ///
    /// Asked of the window at the moment the screen is built rather than
    /// defaulted and corrected, because the row is a different *shape* on a
    /// phone with a home button and a wrong first answer would show it in the
    /// wrong one for a frame. Asked again on appear, for the case where the
    /// window has laid nothing out yet and answers zero.
    @State private var topInset: CGFloat = SafeArea.top
    @State private var bottomInset: CGFloat = SafeArea.bottom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground)

            // The whole screen, and nothing taken off it. The two numbers are
            // what Quiet's own furniture occupies; the web view uses them for
            // the scroll indicator and hands the top one to the page, which
            // starts itself below the clock. See `InstagramWebView`.
            InstagramWebView(
                surface: surface,
                session: session,
                inset: UIEdgeInsets(
                    top: topInset + Self.headerRow,
                    left: 0,
                    bottom: furniture,
                    right: 0
                )
            )
            // Said again here, on the view itself.
            //
            // The stack already ignores it, and the photograph says that was
            // not enough: the page stopped thirty-four points above the bottom
            // of the glass — the home indicator, to the point — with the row
            // floating over a black band instead of over Instagram's next
            // photograph. A representable inside an `ignoresSafeArea` stack is
            // not reliably given the whole of it. Said twice, it is.
            .ignoresSafeArea()

            if !surface.hasLoaded {
                cover
            }

            // The strip behind the clock belongs to the app.
            //
            // This came out once, on the grounds that whatever the app takes
            // off the top comes back as a black band at the bottom. That was
            // wrong twice over: the band at the bottom was Instagram's own
            // floor padding, and taking this away did not fix it — while three
            // separate attempts at persuading Instagram's pinned bar to sit
            // below the clock all came back in a photograph with the wordmark
            // drawn through the battery.
            //
            // So it is back, and it is not a guess. Whatever the page does with
            // its header, nothing of anybody's is ever drawn across the time
            // and the battery, because the app owns those pixels. If the lift
            // works the header sits just below this; if it does not, the header
            // slides underneath and out of sight. Neither is broken.
            VStack(spacing: 0) {
                Color(uiColor: .systemBackground)
                    .frame(height: topInset + Self.headerRow)
                // The hairline under a native bar. Half a point, which is one
                // device pixel on every iPhone Quiet runs on.
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(height: 0.5)
                Spacer(minLength: 0)
            }

            heart

            // Over the cover, so it is there from the first frame rather than
            // arriving with the page.
            quietBar

            statusBarStrip

            overlays
                .padding(.top, topInset + 8)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: surface.hasLoaded)
        .onAppear {
            topInset = SafeArea.top
            bottomInset = SafeArea.bottom
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

    /// The heart, in a row of its own beneath the strip.
    ///
    /// Instagram's own header is behind that strip at every scroll position —
    /// it pins itself to the top of the glass, and three attempts at persuading
    /// it not to all came back in a photograph. Hidden is the right outcome:
    /// nothing is ever drawn through the clock. But the heart went with it, and
    /// the heart was the one thing in that bar that is nowhere else in Quiet.
    ///
    /// So the app draws it. The row is always here, so the page is always told
    /// the same number and the feed never jumps; the heart appears in it once
    /// the page has said where it goes. Quiet guesses no addresses.
    private var heart: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if surface.activity != nil {
                    Button { Touch.tick(); surface.goToActivity() } label: {
                        Image(systemName: "heart")
                            .font(.system(size: 23, weight: .regular))
                            .foregroundStyle(Color(uiColor: .label))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Notifications"))
                }
            }
            .padding(.trailing, 6)
            .frame(height: Self.headerRow)
            Spacer(minLength: 0)
        }
    }

    /// The row under the strip. Forty-four points, which is the height of every
    /// bar on iOS and about what Instagram's own is.
    private static let headerRow: CGFloat = 44

    /// Where the row says you are.
    ///
    /// Instagram's row fills the symbol you are standing on and sets a lighter
    /// capsule behind it, and that mark is most of what makes a row of icons
    /// feel like a place rather than a toolbar. Quiet's says the same thing
    /// about the two screens that are its own.
    private enum Entry: Hashable {
        case home, clock, messages, search, profile
    }

    private var current: Entry {
        if session.isPanelShowing { return .clock }
        if session.isSearchShowing { return .search }

        let path = surface.address?.path ?? "/"
        if path.hasPrefix("/direct") { return .messages }
        if let me = surface.me, path == "/\(me)" || path == "/\(me)/" { return .profile }
        return .home
    }

    /// The row, in whichever shape this phone wears.
    ///
    /// Instagram does not draw the same bar on every iPhone, and neither does
    /// iOS. A phone with a home indicator has a strip along the bottom that
    /// belongs to the system, so the row floats above it: a pill, inset from
    /// both edges, with the page running underneath. A phone with a home button
    /// has no such strip, and there a floating pill leaves a band of nothing
    /// beneath it — so the row *is* the bottom edge, full width, flush, with a
    /// hairline above it, the way every bar on those phones has always been.
    ///
    /// The two are told apart by the only thing that actually distinguishes
    /// them: whether the system reserves anything at the bottom. Not by screen
    /// size, not by a list of model names that goes stale every September.
    private var quietBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if isFloating {
                row
                    .frame(height: Self.barHeight)
                    .padding(.horizontal, 6)
                    // A pill rather than a bar across the whole screen. It is
                    // the app's one piece of furniture; it should sit on the
                    // page rather than cut it off, and the page should be
                    // visible either side of it — and underneath.
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
                    .padding(.horizontal, 22)
                    // Drawn in while the page is moving away under your thumb,
                    // back out the moment it stops or reverses. It never
                    // leaves: a control that disappears is one you hunt for.
                    .scaleEffect(surface.isBarCollapsed ? 0.86 : 1, anchor: .bottom)
                    .opacity(surface.isBarCollapsed ? 0.62 : 1)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86),
                        value: surface.isBarCollapsed
                    )
                    // Low, over the home indicator, the way Instagram's sits.
                    // The page runs on beneath it to the bottom edge of the
                    // glass, which is the whole point of a row that floats.
                    .padding(.bottom, Self.barGap)
            } else {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(height: 0.5)
                    row
                        .frame(height: Self.flushHeight)
                }
                // No shadow and no shrinking. A bar attached to the edge of the
                // screen has nothing to float over and nothing to get out of
                // the way of; both would read as a fault rather than a flourish.
                .background(.regularMaterial)
            }
        }
    }

    /// How much of the bottom of the screen the row stands on. The scroll
    /// indicator is the one thing that still respects it: a scroll bar running
    /// underneath the row reads as a fault.
    private var furniture: CGFloat {
        isFloating ? Self.barHeight + Self.barGap * 2 + bottomInset : Self.flushHeight
    }

    /// Whether this phone reserves a strip at the bottom for itself.
    private var isFloating: Bool { bottomInset > 0 }

    /// The five entries, in the order Instagram uses, with the clock where
    /// Reels would be.
    private var row: some View {
        HStack(spacing: 0) {
            barButton(.home, "house", "house.fill", Text("Home")) {
                surface.goToFeed()
            }
            barButton(.clock, "clock", "clock.fill", Text("Quiet settings")) {
                session.isPanelShowing = true
            }
            barButton(.messages, "paperplane", "paperplane.fill", Text("Messages")) {
                surface.goToMessages()
            }
            barButton(.search, "magnifyingglass", "magnifyingglass", Text("Find someone")) {
                session.isSearchShowing = true
            }
            // Only once the page has said who is signed in. A button that leads
            // nowhere is worse than one that arrives a second late.
            if surface.me != nil {
                myProfileButton
            }
        }
    }

    /// The pill, and the air beneath it. Together they are what the page is
    /// asked to keep clear at the bottom.
    private static let barHeight: CGFloat = 52

    /// A bar attached to the bottom edge is the height every bar on those
    /// phones has been since the first one.
    private static let flushHeight: CGFloat = 49

    /// The last entry, with your own face in it, the way Instagram's row ends.
    /// An outline of a person stands in until the page has handed one over.
    private var myProfileButton: some View {
        let here = current == .profile
        return Button { tap(.profile, { surface.goToMyProfile() }) } label: {
            Group {
                if let face = surface.myFace {
                    Image(uiImage: face)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 27, height: 27)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                Color(uiColor: .label).opacity(here ? 0.95 : 0.25),
                                lineWidth: here ? 2 : 0.5
                            )
                        )
                } else {
                    Image(systemName: here ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color(uiColor: .label))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(mark(here))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Your profile"))
        .accessibilityAddTraits(here ? .isSelected : [])
    }

    private static let barGap: CGFloat = 12

    /// What a tap on the row does.
    ///
    /// Tapping the entry you are already standing on takes you to the top of
    /// it, rather than loading the page you are looking at all over again. Every
    /// tab bar on iOS has done this since there were tab bars, Instagram's
    /// included, and its absence is the kind of thing nobody reports and
    /// everybody feels.
    ///
    /// And every tap gives a tick under the thumb. Instagram's row does; a row
    /// that does not answer the finger reads as a picture of a row.
    private func tap(_ entry: Entry, _ action: () -> Void) {
        Touch.tick()
        if current == entry {
            surface.scrollToTop()
        } else {
            action()
        }
    }

    private func barButton(
        _ entry: Entry,
        _ outline: String,
        _ solid: String,
        _ label: Text,
        action: @escaping () -> Void
    ) -> some View {
        let here = current == entry
        return Button { tap(entry, action) } label: {
            glyph(entry, here, outline, solid)
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(mark(here))
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
        if let name = Self.drawnByInstagram[entry], let icon = surface.icon(name, on: here) {
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

    /// The lighter capsule behind wherever you are.
    ///
    /// Only on the pill. A bar attached to the bottom edge marks its place the
    /// way those bars always have — by filling the symbol and nothing else.
    @ViewBuilder
    private func mark(_ here: Bool) -> some View {
        if here && isFloating {
            Capsule()
                .fill(Color(uiColor: .label).opacity(0.13))
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
        }
    }

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

    private static var insets: UIEdgeInsets? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets
    }
}
