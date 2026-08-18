import SwiftUI

/// Which of the three screens is showing, and the one sheet that can appear over
/// any of them.
@MainActor
struct RootView: View {
    let session: QuietSession

    @State private var surface = WebSurface()
    @State private var isHintShowing = false
    @Environment(\.scenePhase) private var scenePhase

    /// How long the one-time hint about the top edge stays up. Long enough to
    /// read twice, short enough not to be in the way.
    private static let hintDuration: Duration = .seconds(6)

    var body: some View {
        @Bindable var session = session

        content
            .animation(.easeInOut(duration: 0.3), value: session.screen)
            .sheet(isPresented: $session.isPanelShowing) {
                PanelView(session: session, surface: surface) {
                    session.isPanelShowing = false
                }
            }
            .task { session.start() }
            .onChange(of: scenePhase, initial: true) { _, phase in
                session.setForeground(phase == .active)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.screen {
        case .setup:
            SetupView { minutes in
                session.completeSetup(minutes: minutes)
                teachTheGesture()
            }

        case .browsing:
            BrowserScreen(
                session: session,
                surface: surface,
                isHintShowing: isHintShowing
            ) {
                session.isPanelShowing = true
            }

        case .spent:
            CurtainView(
                limitMinutes: session.limit.minutes,
                resetsAt: session.resetsAt
            ) {
                session.isPanelShowing = true
            }
        }
    }

    /// Shown once, right after setup. The app has one hidden gesture and no
    /// tutorial; this is the whole of it. Nothing is stored, because a hint that
    /// only ever appears in the same run of the app that created it does not
    /// need to be remembered.
    private func teachTheGesture() {
        isHintShowing = true
        Task {
            try? await Task.sleep(for: Self.hintDuration)
            isHintShowing = false
        }
    }
}
