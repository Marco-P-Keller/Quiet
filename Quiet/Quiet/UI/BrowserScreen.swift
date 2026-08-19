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
/// The way into the panel is a long press on the status bar: the one strip of
/// the screen that belongs to the phone rather than to the page. It is taught
/// once, on the first run, answered with a haptic so it never feels like a
/// guess, and repeated on the curtain, which has a visible way in.
@MainActor
struct BrowserScreen: View {
    let session: QuietSession
    let surface: WebSurface
    var isHintShowing: Bool
    var onOpenPanel: () -> Void

    /// Twenty points is the shortest status bar any iPhone has; the real height
    /// arrives on the first layout pass.
    @State private var topInset: CGFloat = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            InstagramWebView(surface: surface, session: session)

            if !surface.hasLoaded {
                cover
            }

            statusBarStrip

            overlays
                .padding(.top, topInset + 8)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: surface.hasLoaded)
        .onAppear { topInset = SafeArea.top }
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
            // A hidden gesture is invisible to VoiceOver, which would leave the
            // panel unreachable while browsing. As an element with a button's
            // trait it is the first thing in the rotor, and a double tap opens
            // the panel without any holding at all.
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
        Text("Touch and hold the top edge for settings.")
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
    private func alarm(_ text: String) -> some View {
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
    static var top: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.top ?? 20
    }
}
