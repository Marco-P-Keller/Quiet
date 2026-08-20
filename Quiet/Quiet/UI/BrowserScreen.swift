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
/// There are two ways into the panel.
///
/// A long press on the status bar — the one strip of the screen that belongs to
/// the phone rather than to the site — answered with a haptic so it never feels
/// like a guess. And, on your own profile, a full stop beside Instagram's own
/// settings, which the trim script puts there: settings belong where settings
/// already are, and nowhere else, so nothing of Quiet's sits over the feed.
///
/// The strip along the bottom stays. It began as somewhere to put a mark and
/// earned its place for a duller reason: without it the site's own navigation
/// sits on the home indicator.
@MainActor
struct BrowserScreen: View {
    let session: QuietSession
    let surface: WebSurface
    var isHintShowing: Bool
    var onOpenPanel: () -> Void

    /// Twenty points is the shortest status bar any iPhone has; the real height
    /// arrives on the first layout pass.
    @State private var topInset: CGFloat = 20
    /// The strip Quiet keeps along the bottom, so that Instagram's own
    /// navigation stops sitting on the home indicator.
    @State private var bottomInset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            // The band behind the status bar, in the page's own colour, so the
            // seam does not show.
            Color(uiColor: .systemBackground)

            // Held below the status bar rather than run underneath it. The page
            // does not know it is inside an app and lays its header against the
            // top of whatever it is given, so Instagram's own logo used to sit
            // under the clock. The bottom still runs to the edge, which is where
            // the page's own navigation belongs.
            VStack(spacing: 0) {
                Color.clear.frame(height: topInset)
                InstagramWebView(surface: surface, session: session)
                Color.clear.frame(height: bottomInset)
            }

            if !surface.hasLoaded {
                cover
            }

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
        Paper.page
            .ignoresSafeArea()
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    /// Transparent, and exactly as tall as the status bar, so it never sits over
    /// anything on the page that can be tapped. A tap still does what a tap on
    /// the status bar has always done.
    private var statusBarStrip: some View {
        Color.clear
            .frame(height: topInset)
            .contentShape(Rectangle())
            .onTapGesture { surface.scrollToTop() }
            .onLongPressGesture(minimumDuration: 0.45) {
                Feedback.gestureRecognised()
                onOpenPanel()
            }
            // The mark on the profile is a button in the page, which VoiceOver
            // reads — but only on that one page. Everywhere else this strip is
            // the only way in, and a gesture is invisible to a screen reader,
            // so it carries a label of its own and answers a double tap.
            .accessibilityElement()
            .accessibilityLabel(Text("Quiet settings"))
            .accessibilityHint(Text("Your time today, your daily limit, and finding someone"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onOpenPanel() }
    }

    private var overlays: some View {
        VStack(spacing: 10) {
            if let notice = session.notice {
                NoticeView(notice: notice) { session.dismissNotice(token: $0) }
            }
            if isHintShowing {
                hint
            }
            if !surface.missingResources.isEmpty {
                alarm("Quiet is missing \(surface.missingResources.joined(separator: " and ")). Reinstall from a clean build.")
            }
            if !session.isMemoryReliable {
                alarm("Quiet cannot save to this phone's keychain. Your limit will not survive closing the app.")
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: session.notice)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isHintShowing)
    }

    private var hint: some View {
        Text("Touch and hold the top edge for Quiet's settings, or use the dot on your profile.")
            .font(.quietSmall)
            .foregroundStyle(Paper.page)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Paper.ink.opacity(0.85))
            .clipShape(Capsule())
            .transition(.opacity)
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
