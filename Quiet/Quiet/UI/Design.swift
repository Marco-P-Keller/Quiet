import SwiftUI
import UIKit

/// Quiet's own surfaces look nothing like the site it shows.
///
/// Instagram is bright, dense and full of things to press. The three screens
/// Quiet owns — setup, the panel, the curtain — are paper: warm by day, plain,
/// mostly empty, one thing to read at a time. The difference is the point. When the
/// curtain comes down you should be able to feel that you have left.
enum Paper {
    /// The one dark the app stands in, and every surface of it stands in the
    /// same one.
    ///
    /// It was a warm near-black for as long as Quiet had only its own screens
    /// to think about: paper is warm by day and there is no reason for it to
    /// stop being warm at night. Around somebody else's page that argument
    /// loses, and it loses for the same reason the hairline under the clock
    /// did. Instagram's dark is a cool near-black. The system's — which is what
    /// the ground under the web view, the blank before the first page and the
    /// bar along the bottom were all painted in — is pure black. Quiet's was
    /// brown. Three darks down one screen, meeting at seams, and every seam
    /// visible.
    ///
    /// So: one dark, a shade off black and cool rather than warm, sitting where
    /// the tone Instagram draws its own chrome in already sits. Not sampled
    /// from the page — this is the colour of screens that are up before any
    /// page has loaded and after the day is over — but chosen to stand beside
    /// it without a line where the two meet.
    static let night = UIColor(red: 0.059, green: 0.067, blue: 0.078, alpha: 1)

    /// Background. Warm off-white by day, the app's own dark by night; never
    /// pure white or pure black, both of which glare.
    static let page = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? night
            : UIColor(red: 0.969, green: 0.957, blue: 0.937, alpha: 1)
    })

    /// The pixels Quiet owns *around* somebody else's page: the ground the web
    /// view stands on, the blank held over it until the first page arrives, the
    /// bar along the bottom, and the band behind the clock until the page says
    /// what colour it is.
    ///
    /// The system's own page colour by day, because Instagram's is white and so
    /// is that, and there is nothing to see. By night the system's is pure
    /// black and nothing else on the screen is, so by night it is `night`.
    ///
    /// Not `page`: this is not paper. It is what shows in the half-second
    /// before Instagram paints and in the inch behind a bar, and warm off-white
    /// in front of a white page would be a flash of cream at every cold start.
    static let ground = Color(uiColor: groundColour)

    /// The same colour, for the two places that need a `UIColor` — the web
    /// view's own background and the one behind its scrolling.
    static let groundColour = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? night
            : UIColor.systemBackground.resolvedColor(with: traits)
    }

    /// Body and headline text.
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.937, green: 0.925, blue: 0.902, alpha: 1)
            : UIColor(red: 0.106, green: 0.098, blue: 0.086, alpha: 1)
    })

    /// Everything secondary: the sentence under the heading, the units after
    /// the number.
    static let inkSoft = ink.opacity(0.55)

    /// Hairlines. Barely there on purpose.
    static let rule = ink.opacity(0.12)
}

/// One scale, nine steps, every one of them tied to a system text style so that
/// the whole app grows and shrinks with the reader's own setting. Fixed point
/// sizes would have looked identical on the machine they were designed on and
/// wrong on everybody else's.
extension Font {
    /// The curtain. Said once, and meant.
    static let quietDisplay = Font.system(.largeTitle, design: .serif)
    /// The first line of a screen.
    static let quietTitle = Font.system(.title, design: .serif)
    /// A question.
    static let quietHeading = Font.system(.title2, design: .serif)
    /// Numbers on a wheel.
    static let quietChoice = Font.system(.title3, design: .serif)

    /// Rows, fields, consequences.
    static let quietBody = Font.body
    /// The one thing to press.
    static let quietAction = Font.body.weight(.medium)
    /// The sentence under a heading.
    static let quietNote = Font.subheadline
    /// Hints and asides.
    static let quietSmall = Font.footnote
    /// Version numbers and disclaimers.
    static let quietFine = Font.caption
}

extension View {
    /// The standard page: paper to the edges, text that inherits the app's ink.
    func quietPage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paper.page.ignoresSafeArea())
            .foregroundStyle(Paper.ink)
            .tint(Paper.ink)
    }
}

/// A single, quiet, full-width action. Quiet has no colourful buttons; a button
/// that shouts is a button that wants to be pressed.
struct QuietButton: View {
    var title: String
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.quietAction)
                // Two lines and then it shrinks. A button whose label wraps to
                // four lines stops being a button and starts being a paragraph
                // with a box round it.
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Paper.ink.opacity(isEnabled ? 1 : 0.25))
                .foregroundStyle(Paper.page)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

/// The one piece of physical feedback in the app.
///
/// The app speaks to the hand exactly once.
@MainActor
enum Feedback {
    /// The curtain, arriving while you are looking at the page.
    ///
    /// The same argument as above, for the same reason: a screen that replaces
    /// itself with no warning reads as a fault unless something says the app
    /// meant it. One soft tap, the softest iOS has, once. Not a notification
    /// tone — nothing has gone wrong and nothing has been achieved. It is the
    /// sound of a book being closed, and there is no second one.
    static func dayEnded() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

/// Minutes, said the way a person would say them.
///
/// These are strings the app builds rather than writes, so each one is looked
/// up explicitly. A `Text` with a literal in it is translated by SwiftUI; a
/// `String` assembled in code is not, and would have shipped in English inside
/// a German app.
enum Phrase {
    static func minutes(_ count: Int) -> String {
        // One entry with a plural rule, rather than two strings and an `if`:
        // languages do not agree on how many plurals there are.
        String(localized: "\(count) minutes")
    }

    /// Rounds up, so "0 minutes left" never sits on screen while time is still
    /// running.
    static func remaining(_ seconds: TimeInterval) -> String {
        minutes(max(0, Int(ceil(seconds / 60))))
    }

    static func days(_ count: Int) -> String {
        String(localized: "\(count) days")
    }

    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "tomorrow", "on Tuesday" for the coming week, a date after that.
    static func day(_ day: DayKey, relativeTo today: DayKey, calendar: Calendar = .current) -> String {
        let date = day.start(calendar: calendar)
        let distance = today.days(to: day)
        if distance <= 0 { return String(localized: "today") }
        if distance == 1 { return String(localized: "tomorrow") }
        // Exactly a week out gets a date, not a weekday: "on Tuesday" is the
        // same word as today, and would read as the wrong Tuesday.
        if distance > 1 && distance < 7 {
            return String(localized: "on \(date.formatted(.dateTime.weekday(.wide)))")
        }
        return String(localized: "on \(date.formatted(.dateTime.day().month(.wide)))")
    }
}

/// The arithmetic behind Quiet's mark, in fractions of the app icon's square.
///
/// Every number here is one of `Tools/make-icon.py`'s and every curve is one of
/// its curves. The script renders the mark into a thousand pixels for a home
/// screen and this renders it into eighteen points for the foot of a screen, so
/// the two agree because they are the same drawing rather than because somebody
/// remembered to redo both.
private enum Sandglass {
    static let width: CGFloat = 0.415        // the lids, which are the widest thing
    static let height: CGFloat = 0.585       // lid to lid
    static let cap: CGFloat = 0.044          // a lid
    static let wall: CGFloat = 0.026         // the glass, measured across it
    static let throat: CGFloat = 0.017       // half the opening between the chambers
    static let throatHeight: CGFloat = 0.020 // how much of the neck is parallel
    static let dish: CGFloat = 0.032         // the funnel in the sand still up there
    static let fall: CGFloat = 0.024         // the falling sand, where it lands
    static let pile: CGFloat = 1.35          // how steep the sides of a heap are

    /// The two the script solves rather than chooses: where the sand still up
    /// there comes to, and how tall the heap under it stands, so that the heap
    /// holds exactly what the chamber above it has lost. Finding them again
    /// here would be sixty bisections over a numeric integral to arrive at two
    /// numbers the script already prints, so it prints them:
    ///
    ///     python3 Tools/make-icon.py
    static let level: CGFloat = 0.1112
    static let heap: CGFloat = 0.1500

    /// How much of the ink the sand is, against the glass holding it. The ratio
    /// the icon's own two tones stand in above its field, which is nearly all
    /// of it: two materials, not two colours.
    static let grain: Double = 0.87

    static let half = width / 2
    static let middle = height / 2
    static let lidRadius = cap / 2
    static let shoulder = lidRadius            // where the wall meets the lid at full width
    static let footing = height - lidRadius
    static let roof = cap                      // the underside of a lid, where sand may reach
    static let base = height - cap
    static let neckBelow = middle + throatHeight / 2
    static let neckOutside = throat + wall
    static let span = middle - throatHeight / 2 - shoulder
    static let flare = half - neckOutside
    static let apex = base - heap

    /// How far along the taper this height is: nothing at the throat, all of it
    /// at the lid.
    private static func taper(_ y: CGFloat) -> CGFloat {
        min(max((abs(y - middle) - throatHeight / 2) / span, 0), 1)
    }

    /// Half the width of the glass, outside the wall, at this height.
    ///
    /// A smoothstep, and what matters about it is at its two ends: it leaves
    /// the lid vertically and it arrives at the throat vertically. So there is
    /// a straight side under each lid and a parallel neck in the middle, and
    /// the diagonal is only what is in between — which is an hourglass. A
    /// straight taper is a bow tie, and one still moving at the neck is a
    /// funnel.
    static func outside(_ y: CGFloat) -> CGFloat {
        let t = taper(y)
        return neckOutside + flare * t * t * (3 - 2 * t)
    }

    /// Half the width of the cavity at this height.
    ///
    /// Not `outside(y) - wall`. Taking the wall off horizontally leaves it a
    /// quarter thinner wherever the glass is at its most diagonal, which is
    /// plainly visible and is the usual reason a drawn shape looks slightly
    /// wrong without anybody being able to say where. Off along the normal
    /// instead costs one square root and gives one weight the whole way round.
    static func inside(_ y: CGFloat) -> CGFloat {
        let t = taper(y)
        let slope = flare * 6 * t * (1 - t) / span
        return outside(y) - wall * (1 + slope * slope).squareRoot()
    }

    /// How far out from the middle the sand starts, inside the funnel it has
    /// drained. Sand draining through a hole makes one; a flat top is a photo
    /// of an hourglass nobody has turned over.
    static func funnel(_ y: CGFloat) -> CGFloat {
        let gone = (y - level) / dish
        if gone <= 0 { return inside(y) }
        if gone >= 1 { return 0 }
        return min(inside(level) * (1 - gone).squareRoot(), inside(y))
    }

    /// Half the width of the falling sand, this far below the throat.
    ///
    /// It leaves at the throat's own width and thins, and how fast it thins is
    /// not a taste: the same sand per second through a column going faster is
    /// a column narrower by the fourth root. One constant, fitted so that it
    /// arrives at the heap at `fall`, and the shape of the pour follows.
    static func falling(_ y: CGFloat) -> CGFloat {
        guard y >= neckBelow, y <= apex else { return 0 }
        let ease = (apex - neckBelow) / (pow(throat / (fall / 2), 4) - 1)
        return throat * pow(1 + (y - neckBelow) / ease, -0.25)
    }

    /// Half the width of the heap at this height. Straight-sided with the point
    /// knocked off it, which is what sand landing on sand does.
    ///
    /// The clamp is not belt and braces. `pow` of a negative base with a
    /// fractional exponent is not a small number, it is `nan`, and one `nan`
    /// point is a path SwiftUI draws nothing at all from — so the arithmetic
    /// that says the top of the heap is exactly at the top of the heap has to
    /// be allowed to be a hair either side of it.
    static func heaped(_ y: CGFloat) -> CGFloat {
        guard y >= apex, y <= base else { return 0 }
        return min(inside(base) * pow(max(1 - (base - y) / heap, 0), 1 / pile), inside(y))
    }

    /// Where a point this far right of the middle and this far down the square
    /// falls inside a box the mark has been given.
    static func point(_ x: CGFloat, _ y: CGFloat, in box: CGRect) -> CGPoint {
        let scale = box.height / height
        return CGPoint(x: box.midX + x * scale, y: box.minY + y * scale)
    }

    /// Points down one wall, at enough of them that a curve is a curve rather
    /// than a decision about where its corners go.
    static func wall(
        from start: CGFloat,
        to end: CGFloat,
        _ side: CGFloat,
        _ reach: (CGFloat) -> CGFloat,
        in box: CGRect
    ) -> [CGPoint] {
        let steps = 48
        return (0...steps).map { step in
            let y = start + (end - start) * CGFloat(step) / CGFloat(steps)
            return point(side * reach(y), y, in: box)
        }
    }

    /// A quarter of a lid's rounded end.
    static func corner(
        _ x: CGFloat,
        _ y: CGFloat,
        from start: CGFloat,
        to end: CGFloat,
        in box: CGRect
    ) -> [CGPoint] {
        let steps = 10
        return (0...steps).map { step in
            let angle = start + (end - start) * CGFloat(step) / CGFloat(steps)
            return point(x + lidRadius * cos(angle), y + lidRadius * sin(angle), in: box)
        }
    }
}

/// Quiet's mark: an hourglass, most of the way through.
///
/// The same drawing as the app icon rather than a likeness of it — see
/// `Sandglass` above, and `Tools/make-icon.py`, which is where the numbers are
/// argued with.
///
/// It says the thing a clock cannot. A clock runs for ever; an hourglass runs
/// *out*. It holds a fixed amount, it is spending it, and when it is empty the
/// day is over — which is the whole of this app in one shape, and it is
/// already the shape the row draws for the last five minutes.
///
/// Never large. This is the app signing its name at the foot of a screen, not
/// a logo somebody has to look at: the opening is deliberately not a logo
/// screen and this does not turn it into one. At eighteen points the funnel and
/// the falling sand are a pixel or two each and mostly wash out, which is the
/// right way for them to go: what is left is a glass with an empty top and a
/// heap in the bottom, which was the whole sentence anyway.
struct Hourglass: View {
    /// How tall the glass is. Everything else follows from it.
    var height: CGFloat = 18

    var body: some View {
        ZStack {
            // Stacked and then faded together rather than each faded on its
            // own: the falling sand touches both the sand above it and the heap
            // below, and three translucent fills over one another would draw
            // two dark seams across the one place the mark is trying to say
            // something.
            ZStack {
                Sand(part: .remaining)
                Sand(part: .falling)
                Sand(part: .fallen)
            }
            .opacity(Sandglass.grain)

            // Even-odd, which is the whole of why the cavity is a second
            // subpath rather than a second shape: the silhouette and the hollow
            // inside it are wound the same way, and any other rule fills the
            // glass in solid.
            Glass().fill(style: FillStyle(eoFill: true))
        }
        .foregroundStyle(Paper.ink)
        .frame(width: height * Sandglass.width / Sandglass.height, height: height)
        .accessibilityHidden(true)
    }

    /// The glass itself: the outer silhouette with the cavity taken out of it,
    /// which is the whole of why it is filled even-odd.
    ///
    /// The wall starts at the lid's own centre line rather than under it, where
    /// the two are both exactly `half` from the middle — so they meet with no
    /// step and with no corner poking past the lid's rounded end. The mark this
    /// replaced had four such corners, and at sixty points they were burrs.
    private struct Glass: Shape {
        func path(in box: CGRect) -> Path {
            let half = Sandglass.half
            let lid = Sandglass.lidRadius
            let shoulder = Sandglass.shoulder
            let footing = Sandglass.footing

            var outline = [
                Sandglass.point(-half + lid, 0, in: box),
                Sandglass.point(half - lid, 0, in: box),
            ]
            outline += Sandglass.corner(
                half - lid, shoulder, from: -.pi / 2, to: 0, in: box)
            outline += Sandglass.wall(
                from: shoulder, to: footing, 1, Sandglass.outside, in: box)
            outline += Sandglass.corner(
                half - lid, footing, from: 0, to: .pi / 2, in: box)
            outline.append(Sandglass.point(-half + lid, Sandglass.height, in: box))
            outline += Sandglass.corner(
                -half + lid, footing, from: .pi / 2, to: .pi, in: box)
            outline += Sandglass.wall(
                from: footing, to: shoulder, -1, Sandglass.outside, in: box)
            outline += Sandglass.corner(
                -half + lid, shoulder, from: .pi, to: 1.5 * .pi, in: box)

            var cavity = Sandglass.wall(
                from: Sandglass.roof, to: Sandglass.base, 1, Sandglass.inside, in: box)
            cavity += Sandglass.wall(
                from: Sandglass.base, to: Sandglass.roof, -1, Sandglass.inside, in: box)

            var path = Path()
            path.addLines(outline)
            path.closeSubpath()
            path.addLines(cavity)
            path.closeSubpath()
            return path
        }
    }

    /// The sand, in the three states it is in at once.
    private struct Sand: Shape {
        enum Part {
            /// What is still up there, with the funnel it has drained in it.
            case remaining
            /// What is in the air between the throat and the heap.
            case falling
            /// What has landed.
            case fallen
        }

        var part: Part

        func path(in box: CGRect) -> Path {
            var path = Path()
            switch part {
            case .remaining:
                let level = Sandglass.level
                let neck = Sandglass.neckBelow
                var sand = Sandglass.wall(
                    from: level, to: neck, -1, Sandglass.inside, in: box)
                sand += Sandglass.wall(
                    from: neck, to: level, 1, Sandglass.inside, in: box)
                sand += Sandglass.wall(
                    from: level, to: level + Sandglass.dish, 1, Sandglass.funnel, in: box)
                sand += Sandglass.wall(
                    from: level + Sandglass.dish, to: level, -1, Sandglass.funnel, in: box)
                path.addLines(sand)
            case .falling:
                var stream = Sandglass.wall(
                    from: Sandglass.neckBelow, to: Sandglass.apex, 1, Sandglass.falling,
                    in: box)
                stream += Sandglass.wall(
                    from: Sandglass.apex, to: Sandglass.neckBelow, -1, Sandglass.falling,
                    in: box)
                path.addLines(stream)
            case .fallen:
                var heap = Sandglass.wall(
                    from: Sandglass.apex, to: Sandglass.base, 1, Sandglass.heaped, in: box)
                heap += Sandglass.wall(
                    from: Sandglass.base, to: Sandglass.apex, -1, Sandglass.heaped, in: box)
                path.addLines(heap)
            }
            path.closeSubpath()
            return path
        }
    }
}
