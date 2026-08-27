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

    /// How the app looks and what it says, as against what it promises.
    ///
    /// Handed down rather than put in the environment: several views need it,
    /// and a missing environment value is a crash rather than a compile error.
    /// Built in `QuietApp` rather than here, because the session reads it too
    /// and one of the two would otherwise have been holding a second copy.
    let preferences: Preferences

    @State private var surface = WebSurface()
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
        content
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.screen)
            // An overlay rather than a stack, and the difference is not a
            // matter of taste.
            //
            // Wrapping the app in a `ZStack` to hold the opening screen put a
            // container between the app and the window, and that container
            // respects the safe area. The browsing screen reports the height of
            // the whole glass, because it ignores the safe area on purpose — so
            // it was a view eight hundred and seventy-four points tall being
            // centred in a region seven hundred and eighty-one points tall, and
            // it hung twelve and a half points off the bottom of the screen.
            //
            // Which is why moving the floating row two millimetres up did
            // nothing: it moved, and then the whole screen it sits on moved
            // down by almost exactly the same amount. Three photographs and two
            // wrong explanations went past before CI measured the drawn thing
            // and made the arithmetic visible.
            //
            // An overlay is laid over the view and sized to it. The view is
            // proposed exactly what it was proposed before this screen existed,
            // which is the whole point.
            .overlay {
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
                // The last moment the page is certain to still be there. iOS
                // discards web views under memory pressure without asking, so
                // anything not written down now is a feed from the top the next
                // time somebody opens the app. See `ThePlace`.
                if phase != .active { surface.keepThePlace() }
            }
            // Only this one transition. Opening the app onto a day that was
            // already gone goes from setup to the curtain, and a phone that
            // buzzes at you for a thing you did yesterday is a phone that has
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
                    surface.visit(url)
                    session.isSearchShowing = false
                }
            )
        }
    }
}
