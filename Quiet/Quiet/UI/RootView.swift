import SwiftUI

/// Which of the three screens is showing, and the two of Quiet's own that can
/// appear over the curtain.
///
/// While Instagram is on screen, the settings behind the clock and the search
/// for a person are *pages* rather than sheets: they are two of the five
/// entries in the row along the bottom, and a sheet would take that row away
/// with the rest of the screen. See `BrowserScreen`.
///
/// The curtain is the one place they are still sheets, because there is no row
/// down there to be part of — the day is over, and the only thing on the screen
/// is the sentence saying so.
@MainActor
struct RootView: View {
    let session: QuietSession

    @State private var surface = WebSurface()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.screen)
            .task {
                session.start()
                #if DEBUG
                Rehearsal.open(session)
                #endif
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                session.setForeground(phase == .active)
            }
            // Only this one transition. Opening the app onto a day that was
            // already gone goes from setup to the curtain, and a phone that
            // buzzes at you for a thing you did yesterday is a phone that has
            // misunderstood the app.
            .onChange(of: session.screen) { was, now in
                if was == .browsing, now == .spent { Feedback.dayEnded() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.screen {
        case .setup:
            SetupView { minutes in
                session.completeSetup(minutes: minutes)
            }

        case .browsing:
            BrowserScreen(session: session, surface: surface)

        case .spent:
            curtain
        }
    }

    private var curtain: some View {
        @Bindable var session = session

        return CurtainView(
            limitMinutes: session.limit.minutes,
            resetsAt: session.resetsAt,
            notice: session.notice,
            onExpireNotice: { session.dismissNotice(token: $0) }
        ) {
            session.isPanelShowing = true
        }
        .sheet(isPresented: $session.isPanelShowing) {
            PanelView(
                session: session,
                surface: surface,
                onFindSomeone: {
                    session.isPanelShowing = false
                    session.isSearchShowing = true
                },
                onDismiss: { session.isPanelShowing = false }
            )
        }
        .sheet(isPresented: $session.isSearchShowing) {
            SearchView(
                surface: surface,
                onDone: { session.isSearchShowing = false },
                onOpen: { url in
                    surface.open(url)
                    session.isSearchShowing = false
                }
            )
        }
    }
}
