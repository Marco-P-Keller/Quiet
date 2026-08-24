import StoreKit
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
    /// How the app looks, as against what it promises. Handed down rather than
    /// put in the environment: three views need it, and a missing environment
    /// value is a crash rather than a compile error.
    @State private var preferences = Preferences()
    /// Whether the app has earned the right to ask what you think of it.
    @State private var applause = Applause()
    /// True for the first second and a half of a launch.
    @State private var isOpening = Opening.shows
    /// The App Store's own question, and nothing of Quiet's.
    ///
    /// Everything about the sheet — the stars, the wording, the fact that it
    /// can be dismissed without answering, and the cap of three a year that
    /// iOS applies whatever any app asks for — belongs to the system. An app
    /// that drew its own version could nag, and could imply a rating had been
    /// left when none had.
    ///
    /// It is a request rather than a command, and nothing here can tell whether
    /// anything appeared. That is why `Applause` marks the question as put when
    /// it is asked and not when a star is pressed: asking twice because the
    /// first went quietly nowhere is the exact behaviour this is avoiding.
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            content
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.screen)

            if isOpening {
                OpeningView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: isOpening)
        .task {
            session.start()
            #if DEBUG
            Rehearsal.open(session)
            #endif
        }
        .task {
            guard !Opening.stays else { return }
            try? await Task.sleep(for: OpeningView.held)
            isOpening = false
        }
        .task(id: scenePhase) { await countTowardsAsking() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            session.setForeground(phase == .active)
        }
        // Only this one transition. Opening the app onto a day that was
        // already gone goes from setup to the curtain, and a phone that buzzes
        // at you for a thing you did yesterday is a phone that has
        // misunderstood the app.
        .onChange(of: session.screen) { was, now in
            if was == .browsing, now == .spent { Feedback.dayEnded() }
        }
    }

    /// Count the app's time on screen, and put the question once it is owed.
    ///
    /// Cancelled and restarted every time the app comes and goes, which is what
    /// makes it honest: the time it banks is time the app was actually in front
    /// of somebody, and a launch that is backgrounded after ten seconds banks
    /// ten seconds. The sleep is the whole of the waiting — nothing polls.
    ///
    /// Not over the opening screen and not over the curtain. The end of the day
    /// is the one moment in Quiet that is meant to be felt, and a five-star
    /// sheet arriving on top of it would be the app asking to be praised for
    /// the thing it just took away.
    private func countTowardsAsking() async {
        guard scenePhase == .active, !applause.asked else { return }
        applause.enter()
        defer { applause.leave() }

        while !applause.isDue {
            let wait = applause.remaining
            guard wait > 0 else { break }
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            applause.bank()
        }

        guard applause.isDue, session.screen == .browsing, !isOpening else { return }
        applause.markAsked()
        requestReview()
    }

    @ViewBuilder
    private var content: some View {
        switch session.screen {
        case .setup:
            SetupView { minutes in
                session.completeSetup(minutes: minutes)
            }

        case .browsing:
            BrowserScreen(session: session, surface: surface, preferences: preferences)

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
                preferences: preferences,
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
