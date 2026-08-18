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
/// once, on the first run, and repeated on the curtain, which also has a way in.
@MainActor
struct BrowserScreen: View {
    let session: QuietSession
    let surface: WebSurface
    var isHintShowing: Bool
    var onOpenPanel: () -> Void

    /// Twenty points is the shortest status bar any iPhone has; the real height
    /// arrives on the first layout pass.
    @State private var topInset: CGFloat = 20

    var body: some View {
        // The stack ignores the safe area so that its top edge is the top of the
        // screen. Everything inside is then positioned against the glass, which
        // is what both the strip and the notices want.
        ZStack(alignment: .top) {
            InstagramWebView(surface: surface, session: session)

            statusBarStrip

            overlays
                .padding(.top, topInset + 8)
        }
        .ignoresSafeArea()
        .onAppear { topInset = SafeArea.top }
    }

    /// Transparent, and exactly as tall as the status bar, so it never sits over
    /// anything on the page that can be tapped. A tap still does what a tap on
    /// the status bar has always done.
    private var statusBarStrip: some View {
        Color.clear
            .frame(height: topInset)
            .contentShape(Rectangle())
            .onTapGesture { surface.scrollToTop() }
            .onLongPressGesture(minimumDuration: 0.45) { onOpenPanel() }
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
                brokenBuildWarning
            }
        }
        .animation(.easeInOut(duration: 0.22), value: session.notice)
        .animation(.easeInOut(duration: 0.22), value: isHintShowing)
    }

    private var hint: some View {
        Text("Touch and hold the top edge for settings.")
            .font(.system(size: 13))
            .foregroundStyle(Paper.page)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Paper.ink.opacity(0.85))
            .clipShape(Capsule())
            .transition(.opacity)
    }

    /// If the trim files did not make it into the bundle, Reels come back and
    /// the app silently becomes the thing it exists to replace. Better to say so
    /// on screen than to let anyone find out by scrolling.
    private var brokenBuildWarning: some View {
        Text("Quiet is missing \(surface.missingResources.joined(separator: " and ")). Reinstall from a clean build.")
            .font(.system(size: 13, weight: .medium))
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
