import SwiftUI

/// Which of the three screens is showing, and the one sheet that can appear over
/// any of them.
@MainActor
struct RootView: View {
    let session: QuietSession

    @State private var surface = WebSurface()
    @State private var isHintShowing = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long the one-time hint about the top edge stays up. Long enough to
    /// read twice, short enough not to be in the way.
    private static let hintDuration: Duration = .seconds(6)

    var body: some View {
        @Bindable var session = session

        content
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.screen)
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
                SearchView(surface: surface) { url in
                    surface.open(url)
                }
            }
            .task {
                session.start()
                #if DEBUG
                Rehearsal.open(session)
                #endif
                if session.screen == .browsing, session.isLearningTheGesture {
                    sayWhereQuietIs()
                }
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
                sayWhereQuietIs()
            }

        case .browsing:
            BrowserScreen(
                session: session,
                surface: surface,
                isHintShowing: isHintShowing
            )

        case .spent:
            CurtainView(
                limitMinutes: session.limit.minutes,
                resetsAt: session.resetsAt,
                notice: session.notice,
                onExpireNotice: { session.dismissNotice(token: $0) }
            ) {
                session.isPanelShowing = true
            }
        }
    }

    /// The app has no tutorial; this is the whole of it. One sentence saying
    /// where Quiet's own settings are, shown after setup and again on the first
    /// launch of each of the next two days, after which it assumes you know.
    private func sayWhereQuietIs() {
        isHintShowing = true
        Task {
            try? await Task.sleep(for: Self.hintDuration)
            isHintShowing = false
        }
    }
}
