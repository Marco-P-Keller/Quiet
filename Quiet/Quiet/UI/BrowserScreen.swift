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
/// Quiet keeps one row of its own along the bottom: a search, and a clock for
/// its settings. Two icons, always in the same place, on every page.
///
/// They lived inside Instagram's own navigation for a while, which is where
/// they belonged and where they twice failed to appear — a bar built by
/// somebody else, out of generated class names, in a layout that has no room
/// for a fourth child. Reliability wins that argument. A control you cannot
/// find is worth less than one in a slightly worse place.
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
                inset: UIEdgeInsets(top: topInset, left: 0, bottom: barHeight + bottomInset, right: 0)
            )

            if !surface.hasLoaded {
                cover
            }

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

    /// Quiet's own bar, for the pages that have none of their own.
    ///
    /// Instagram drops its navigation on some screens — messages is the one
    /// people notice — and a search and a clock that come and go with somebody
    /// else's layout are worse than useless. So on those pages Quiet draws the
    /// two of them itself, in the page's own colours, in the same corner of the
    /// screen they occupy everywhere else.
    ///
    /// Everywhere the page *does* have a bar, these two live inside it, which is
    /// where they belong: one bar, not two.
    private var quietBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Divider().overlay(Color(uiColor: .separator))
            HStack(spacing: 0) {
                barButton("magnifyingglass", Text("Find someone")) {
                    session.isSearchShowing = true
                }
                barButton("clock", Text("Quiet settings")) {
                    session.isPanelShowing = true
                }
            }
            .frame(height: barHeight)
            .padding(.bottom, bottomInset)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private let barHeight: CGFloat = 46

    private func barButton(_ symbol: String, _ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
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
