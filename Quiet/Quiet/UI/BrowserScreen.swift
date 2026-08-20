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
/// The pill draws itself in while the page moves away under your thumb and
/// comes back out when it stops. It never leaves, because a control that
/// disappears is a control you end up hunting for.
///
/// The two Quiet needed lived inside Instagram's bar for a while, which is
/// where they belonged and where they twice failed to appear: a row built by
/// somebody else, out of generated class names, with no room for a fourth
/// child. Two silent failures is the argument settled. Instagram's row is taken
/// out — after the signed-in name has been read from it, which is the one thing
/// only that row knows.
///
/// The top is the app's too. Instagram's iOS app draws its header natively and
/// runs the page underneath it; Quiet does the same, because five attempts at
/// letting the site keep its own header taught the same lesson five times — a
/// bar the page sticks to the top of the glass will sooner or later be under
/// the clock.
///
/// The web view keeps the whole screen and is told which parts of it are spoken
/// for, so nothing of Quiet's ever covers the page.
@MainActor
struct BrowserScreen: View {
    let session: QuietSession
    let surface: WebSurface

    /// Twenty points is the shortest status bar any iPhone has; the real height
    /// arrives on the first layout pass.
    @State private var topInset: CGFloat = 20
    @State private var bottomInset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground)

            // The whole screen, with the parts that are spoken for declared as
            // an inset rather than taken away. See `InstagramWebView` for what
            // the two attempts before this one did to Instagram's header.
            InstagramWebView(
                surface: surface,
                session: session,
                inset: UIEdgeInsets(
                    top: topInset + Self.headerHeight,
                    left: 0,
                    bottom: Self.barHeight + Self.barGap * 2 + bottomInset,
                    right: 0
                )
            )

            if !surface.hasLoaded {
                cover
            }

            header

            // Over the cover, so it is there from the first frame rather than
            // arriving with the page.
            quietBar

            statusBarStrip

            overlays
                .padding(.top, topInset + Self.headerHeight + 8)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: surface.hasLoaded)
        .onAppear {
            topInset = SafeArea.top
            bottomInset = SafeArea.bottom
        }
    }

    /// The header, drawn by the app.
    ///
    /// Instagram's iOS app puts native chrome across the top: the status bar,
    /// a title row, a hairline, and the page beneath. Quiet does the same, and
    /// for the same reason it had to in the end — five attempts went into
    /// leaving the site's own header in place and persuading it to stay clear
    /// of the clock, and each worked in one state and failed in another. A bar
    /// stuck to the top of the glass is stuck to the top of the glass. The page
    /// is allowed to do that; it just cannot be the app's header while it does.
    ///
    /// So the site's header goes (see `takeTopBar` in trim.js) and this one
    /// takes its place. It cannot collide with anything, because it is drawn
    /// against the safe area rather than against a viewport, and the page is
    /// told to start underneath it.
    ///
    /// It does not hide as you scroll. Instagram's does, and matching that
    /// would mean animating the page's inset in step with a header the page
    /// knows nothing about — a header and a page disagreeing about where the
    /// top is, sixty times a second. Still is better than nearly.
    private var header: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.clear.frame(height: topInset)
                HStack(spacing: 0) {
                    Text(verbatim: "Instagram")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    // The heart, and only once the page has said where it goes.
                    // It is the one control Instagram's header carried that was
                    // nowhere else in Quiet.
                    if surface.activity != nil {
                        Button { surface.goToActivity() } label: {
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
                .padding(.leading, 16)
                .padding(.trailing, surface.activity == nil ? 16 : 4)
                .frame(height: Self.headerHeight)
            }
            .background(Color(uiColor: .systemBackground))

            // The hairline under a native bar. Half a point, which is one
            // device pixel on every iPhone Quiet runs on.
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 0.5)

            Spacer(minLength: 0)
        }
    }

    /// The title row, beneath the status bar. Forty-four points is the height
    /// of every native bar on iOS, which is what this is pretending to be —
    /// and, on the feed, roughly what Instagram's own bar was.
    private static let headerHeight: CGFloat = 44

    /// Quiet's own paper, held over the web view until the first page settles.
    /// A cold launch should look like the app deciding to start, not like a
    /// blank browser.
    private var cover: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    /// The pill.
    private var quietBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                barButton("house", Text("Home")) { surface.goToFeed() }
                barButton("clock", Text("Quiet settings")) {
                    session.isPanelShowing = true
                }
                barButton("paperplane", Text("Messages")) { surface.goToMessages() }
                barButton("magnifyingglass", Text("Find someone")) {
                    session.isSearchShowing = true
                }
                // Only once the page has said who is signed in. A button that
                // leads nowhere is worse than one that arrives a second late.
                if surface.me != nil {
                    myProfileButton
                }
            }
            .frame(height: Self.barHeight)
            .padding(.horizontal, 4)
            // A pill rather than a bar across the whole screen. It is the app's
            // one piece of furniture; it should sit on the page rather than cut
            // it off, and the page should be visible either side of it.
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color(uiColor: .separator).opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
            .padding(.horizontal, 26)
            // Drawn in while the page is moving away under your thumb, back out
            // the moment it stops or reverses. It never leaves: a control that
            // disappears is a control you end up hunting for.
            .scaleEffect(surface.isBarCollapsed ? 0.86 : 1, anchor: .bottom)
            .opacity(surface.isBarCollapsed ? 0.62 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86),
                value: surface.isBarCollapsed
            )
            .padding(.bottom, bottomInset + Self.barGap)
        }
    }

    /// The pill, and the air beneath it. Together they are what the page is
    /// asked to keep clear at the bottom.
    private static let barHeight: CGFloat = 52

    /// The last entry, with your own face in it, the way Instagram's row ends.
    /// An outline of a person stands in until the page has handed one over.
    private var myProfileButton: some View {
        Button { surface.goToMyProfile() } label: {
            Group {
                if let face = surface.myFace {
                    Image(uiImage: face)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 27, height: 27)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color(uiColor: .label).opacity(0.25), lineWidth: 0.5))
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(Color(uiColor: .label).opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Your profile"))
    }
    private static let barGap: CGFloat = 10

    private func barButton(_ symbol: String, _ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Color(uiColor: .label).opacity(0.85))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
