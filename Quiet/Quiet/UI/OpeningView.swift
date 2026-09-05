import SwiftUI

/// The first second and a half.
///
/// An app that opens straight onto Instagram is an app you are inside before
/// you have decided to be. This is the pause: one sentence, on Quiet's own
/// paper, saying what the app is for — and then it gets out of the way and
/// never appears again until the next time you choose to open it.
///
/// It is not a progress indicator and does not pretend to be one. Nothing is
/// waiting on it; the web view loads behind it, so the time is spent rather
/// than wasted. It is also not a logo screen. There is a sentence to read, and
/// somebody who reads it has had the thought the app exists to prompt.
struct OpeningView: View {
    var body: some View {
        ZStack {
            Paper.page

            VStack(spacing: 14) {
                Text("No more doomscrolling.")
                    .font(.quietTitle)
                    .foregroundStyle(Paper.ink)
                Text("Instagram, on your terms.")
                    .font(.quietNote)
                    .foregroundStyle(Paper.inkSoft)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            VStack {
                Spacer(minLength: 0)
                // The app signing its name, which is not the same as a logo
                // screen: it is at the foot, it is the size of the word next
                // to it, and nobody has to look at it. What it buys is that
                // the thing on the home screen and the thing that opens are
                // recognisably the same app.
                Hourglass(height: 16)
                Text(verbatim: "Quiet")
                    .font(.quietFine)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 7)
                    .padding(.bottom, 28)
            }
        }
        .ignoresSafeArea()
        // Read by the eye, not by VoiceOver. Somebody using the screen reader
        // is already being handed the screen underneath, and an announcement
        // that interrupts itself a second later is worse than none.
        .accessibilityHidden(true)
    }

    /// How long it is up before it starts to go.
    ///
    /// Long enough to read six words and no longer. An opening you have to wait
    /// out is one you learn to resent, and this one is in front of somebody who
    /// has already decided what they came to do.
    static let held: Duration = .seconds(1.4)

    /// And how long it is up when the page behind it is already there.
    ///
    /// The sentence is the reason this screen exists, so there is a floor and
    /// it is not zero. What there is no reason for is the second half of the
    /// wait *after* Instagram has painted — which is most of what a warm launch
    /// is: the place is put back without a load, the feed is on the glass in a
    /// tenth of a second, and Quiet went on showing its own paper over the top
    /// of it for more than a second longer because a timer said so.
    ///
    /// The slow launch is unchanged. Nothing here shortens a wait that is real;
    /// it only stops adding to one that is over. See `RootView`.
    static let least: Duration = .seconds(1.0)

    /// What is left of the wait, once the least of it has been spent.
    static var rest: Duration { held - least }
}

/// Whether this launch shows the opening, and for how long.
///
/// Wrapped up here rather than asked in the view, because both answers are
/// about a rehearsal and neither exists in a build anybody can install.
enum Opening {
    /// True on every launch that a person makes.
    static var shows: Bool {
        #if DEBUG
        return !Rehearsal.skipsOpening
        #else
        return true
        #endif
    }

    /// True only when a machine has been asked to photograph it.
    static var stays: Bool {
        #if DEBUG
        return Rehearsal.holdsOpening
        #else
        return false
        #endif
    }
}

#Preview {
    OpeningView()
}
