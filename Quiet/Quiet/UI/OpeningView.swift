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
/// than wasted. There is a sentence to read, and somebody who reads it has had
/// the thought the app exists to prompt.
///
/// ## The glass
///
/// The mark above the sentence is not a logo being shown off. This is the only
/// screen in the app where the hourglass is drawn large, and what it does with
/// the size is *run*: brim full when the screen arrives, and at the pose the
/// app icon is drawn in by the time the screen goes. Every frame of that is
/// solved rather than posed — the funnel deepens, the column falls, the heap
/// rises, and what the heap holds is exactly what the chamber above it has
/// lost. See `Sandglass.pose(at:)`.
///
/// Which is the argument for it being here at all. A logo that fades up says
/// the name of the app. This says what the app *is*: a fixed amount, being
/// spent, starting now — the same sentence the words underneath are making,
/// made by the thing that will still be in the corner of the screen an hour
/// later. And the person who tapped an icon a second ago watches that icon
/// arrive at the picture it is on their home screen.
///
/// It does not finish. The screen leaves while the sand is still falling,
/// because that is the true thing to say about a day that has just started.
struct OpeningView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How tall the glass is, on a screen where everything else grows with the
    /// reader's own text size.
    ///
    /// Capped, and the cap is the whole reason this is not simply scaled. At
    /// the largest setting anybody's phone offers, the two lines under it are
    /// already three lines each; a mark grown by the same multiple would push
    /// them off a small screen between them.
    @ScaledMetric(relativeTo: .title) private var scaled: CGFloat = 56

    /// The air between the glass and the sentence, which does grow, because a
    /// gap that stayed put under type twice the size would close.
    @ScaledMetric(relativeTo: .title) private var gap: CGFloat = 42

    /// When the first frame was drawn, which is what everything that moves is
    /// measured from.
    ///
    /// The timeline's own first date rather than `onAppear`, and the difference
    /// is not a nicety: this date *is* a frame, by construction, and a
    /// lifecycle callback is a moment that is not one. Zero elapsed should mean
    /// the first thing on the glass, and with this it does — a recording of a
    /// launch with the number drawn on it reads 0.000 on the first frame the
    /// simulator captured.
    ///
    /// A box rather than a piece of state, because the only place that date
    /// exists is inside a body pass. Nothing observes this and nothing is
    /// invalidated by it, so writing it there costs nothing; making it `@State`
    /// and assigning would schedule a second pass to say what the first one
    /// already knew.
    @State private var clock = Clock()

    private final class Clock {
        private var first: Date?

        func since(_ now: Date) -> TimeInterval {
            guard let first else {
                first = now
                return 0
            }
            return now.timeIntervalSince(first)
        }
    }

    var body: some View {
        ZStack {
            Paper.page

            if isStill {
                sheet(.settled)
            } else {
                // One clock, read once a frame, with everything on the screen a
                // function of it — rather than four pieces of state and four
                // animations that then have to be kept in step by hand. The
                // sand is what forces it: its shape is solved out of a number,
                // which is not something SwiftUI can interpolate two poses of.
                TimelineView(.animation) { timeline in
                    sheet(.at(clock.since(timeline.date)))
                }
            }
        }
        .ignoresSafeArea()
        // Read by the eye, not by VoiceOver. Somebody using the screen reader
        // is already being handed the screen underneath, and an announcement
        // that interrupts itself a second later is worse than none.
        .accessibilityHidden(true)
    }

    /// Whether this launch shows the run at all.
    ///
    /// Two reasons not to, and at bottom they are the same reason. Somebody who
    /// has asked for less motion has asked for less motion. And a rehearsal is
    /// a photograph — a screen still moving when the shutter goes is a screen
    /// no two runs of the workflow agree about, which is the one thing a staged
    /// launch exists to rule out. Both get the settled pose, which is the mark
    /// this screen drew before it could move.
    private var isStill: Bool { reduceMotion || Opening.stays }

    private func sheet(_ frame: Frame) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Hourglass(height: min(scaled, 84), run: frame.run)
                    .padding(.bottom, gap)
                    .opacity(frame.mark)
                    // A hair under its own size, arriving at it. Not a bounce
                    // and not a spin: the glass is a thing that was already
                    // there being brought into focus, and six percent is as
                    // much as that can be said with before it becomes an
                    // entrance.
                    .scaleEffect(0.94 + 0.06 * frame.mark)

                Text("No more doomscrolling.")
                    .font(.quietTitle)
                    .foregroundStyle(Paper.ink)
                    .padding(.bottom, 14)
                    .modifier(Arriving(by: frame.lead))

                Text("Instagram, on your terms.")
                    .font(.quietNote)
                    .foregroundStyle(Paper.inkSoft)
                    .modifier(Arriving(by: frame.second))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            VStack {
                Spacer(minLength: 0)
                Text(verbatim: "Quiet")
                    .font(.quietFine)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.bottom, 28)
                    .opacity(frame.name)
            }
        }
    }

    /// How a line of type arrives: up out of nothing, and into focus.
    ///
    /// Three small things at once, none of them large enough to be noticed on
    /// its own, which is the difference between type that appears and type that
    /// arrives.
    ///
    /// Not letterspacing, which is the other way to do this and the tempting
    /// one. Tracking is layout: a line whose spacing is still settling can wrap
    /// somewhere different between one frame and the next, and at the largest
    /// text size these two lines are wrapping already. A reflow halfway through
    /// a fade is the one failure here that would actually be seen.
    private struct Arriving: ViewModifier {
        var by: Double

        func body(content: Content) -> some View {
            content
                .opacity(by)
                .blur(radius: 4 * (1 - by))
                .offset(y: 7 * (1 - by))
        }
    }

    /// One frame of the opening: where the sand is, and how far each of the
    /// three things written on the screen has arrived.
    private struct Frame {
        /// How far through the glass, 0 to 1. See `Hourglass.run`.
        var run: CGFloat = 1
        var mark: Double = 1
        var lead: Double = 1
        var second: Double = 1
        var name: Double = 1

        /// Everything arrived, and the sand where the icon has it.
        static let settled = Frame()

        /// The beat before the sand lets go.
        ///
        /// The glass has to be on the screen, and be *seen* to be there, before
        /// it can be seen to start. Just under a third of a second looks like a
        /// great deal to spend out of one and four tenths, and the first version
        /// spent a tenth — which was wrong twice over, and a recording of a
        /// launch is what said so.
        ///
        /// The first is ordinary: sand let go into a mark that is still fading
        /// up starts where nobody is looking.
        ///
        /// The second is the launch itself. The app draws its first frame at
        /// once and correctly, and then stalls for something over two tenths of
        /// a second while the web view is built — one frame on the glass, held,
        /// and then the clock resumes a fifth of a second further on than it
        /// was. Everything scheduled inside that window happens behind a still
        /// picture. With the sand let go at a tenth, the whole of the crater
        /// being dug and the first of the fall happened in there, and the pose
        /// the screen most wants to open on — the full one — was never once on
        /// the glass.
        ///
        /// So the beat is long enough to cover the stall. What it buys is that
        /// the first thing anybody sees is a full glass, and the next thing
        /// they see is it letting go.
        static let letGo: TimeInterval = 0.32

        static func at(_ elapsed: TimeInterval) -> Frame {
            Frame(
                // Straight, with nothing eased into it or out of it, because
                // that is what an hourglass does and it is the whole reason a
                // glass of sand can be used to measure anything at all. A tank
                // empties more slowly as it empties; this does not.
                run: CGFloat(part(elapsed, from: letGo, over: OpeningView.wait - letGo)),
                mark: arriving(part(elapsed, from: 0, over: 0.24)),
                // All three are over by the second the warm launch cuts the
                // screen off at. The sand is deliberately not — see `least`.
                lead: arriving(part(elapsed, from: 0.36, over: 0.52)),
                second: arriving(part(elapsed, from: 0.48, over: 0.52)),
                name: arriving(part(elapsed, from: 0.56, over: 0.44))
            )
        }

        /// How far between two moments a moment is.
        private static func part(
            _ elapsed: TimeInterval, from start: TimeInterval, over span: TimeInterval
        ) -> Double {
            min(max((elapsed - start) / span, 0), 1)
        }

        /// Quickly, then slowing: how a thing that has been let go arrives.
        private static func arriving(_ part: Double) -> Double {
            1 - pow(1 - part, 3)
        }
    }

    /// How long it is up before it starts to go.
    ///
    /// Long enough to read six words and no longer. An opening you have to wait
    /// out is one you learn to resent, and this one is in front of somebody who
    /// has already decided what they came to do.
    ///
    /// In seconds as well as in `Duration`, because one thing waits on it and
    /// another draws against it, and two spellings of one and four tenths that
    /// could drift apart is how the sand would come to stop somewhere that is
    /// not the icon.
    static let wait: TimeInterval = 1.4
    static var held: Duration { .seconds(wait) }

    /// And how long it is up when the page behind it is already there.
    ///
    /// The sentence is the reason this screen exists, so there is a floor and
    /// it is not zero. What there is no reason for is the second half of the
    /// wait *after* Instagram has painted — which is most of what a warm launch
    /// is: the place is put back without a load, the feed is on the glass in a
    /// tenth of a second, and Quiet went on showing its own paper over the top
    /// of it for more than a second longer because a timer said so.
    ///
    /// The sand is about two-thirds down when a warm launch cuts it off, and
    /// nothing is done about that on purpose. It is a glass that is still
    /// running, which is the true thing to say about a day that has just
    /// started; a mark hurried to its finish so the screen could leave tidily
    /// would be the animation lying about what it is for.
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
