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

    /// A stretch of time long enough to have hours in it: "40 minutes",
    /// "1 hour, 20 minutes".
    ///
    /// The system's own units formatter rather than a sentence of Quiet's,
    /// which is not laziness — it is the only way the German build says
    /// "1 Stunde, 20 Minuten" without somebody having written and translated a
    /// plural rule for hours as well as minutes. Everywhere the app talks about
    /// *today* it still says minutes and only minutes, because a daily limit is
    /// a number of minutes; this is for the week and the month behind you,
    /// where minutes alone stop being readable.
    static func span(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        guard whole >= 60 else { return String(localized: "under a minute") }
        // Spelled out rather than folded into a ternary: the `allowed:` set is
        // generic enough that a conditional inside it loses the contextual type
        // and the compiler stops being able to name the units at all.
        let allowed: Set<Duration.UnitsFormatStyle.Unit> = whole >= 3600 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(whole).formatted(.units(allowed: allowed, width: .wide))
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

    // MARK: - The run
    //
    // And the three the same script solves for the glass *arriving* at that
    // pose, which is what the opening screen draws.
    //
    // A pose part of the way there cannot be had by scaling the two above.
    // Each is solved out of a volume, and half a volume is not half a length.
    // What came back from solving the whole path, though, was shorter than a
    // table, because two of the three things that move turn out to move
    // straight:
    //
    //   * The funnel is dug first, and it costs a quarter of the run before
    //     the surface has moved at all. That is not a liberty taken to make
    //     the opening more interesting — the chamber is at its widest under
    //     the top lid, so the dish draining sand digs into a full one holds a
    //     great deal. It is what `dish` is worth in a chamber this shape.
    //   * It deepens at a constant rate, because its width goes as the square
    //     root of its depth, so its volume goes as its depth.
    //   * The heap rises at a constant rate, for a related reason: a heap of
    //     this profile holds a fixed multiple of its own height.
    //
    // Which leaves the surface, and that one is a curve.
    //
    //     python3 Tools/make-icon.py

    /// How much of the run is spent digging the funnel.
    static let crater: CGFloat = 0.2624

    /// And how much is over before the first grain lands. Two hundredths of
    /// it: a couple of frames, which is about what falling that far takes.
    static let landing: CGFloat = 0.0240

    /// Where the surface has got to, across the rest of the run. Thirteen
    /// points describe it to within a hundredth of a point at the size the
    /// opening draws the mark. The first is the underside of the lid and the
    /// last is `level`, which is what makes the run end at the icon.
    static let levels: [CGFloat] = [
        0.0440, 0.0481, 0.0523, 0.0567,
        0.0613, 0.0660, 0.0711, 0.0764,
        0.0822, 0.0883, 0.0951, 0.1026,
        0.1112,
    ]

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

    /// Where the sand is, this far through the run.
    ///
    /// One value rather than four, because the four are one state and every
    /// shape below needs more than one of them.
    struct Pose {
        /// Where the surface of what is left has got to.
        var level: CGFloat
        /// How deep the funnel in it is.
        var dish: CGFloat
        /// How tall the heap under it stands.
        var heap: CGFloat
        /// Where the falling sand ends: the top of the heap, or — for the two
        /// frames before the first grain lands — as far as the column's front
        /// has fallen.
        var front: CGFloat
    }

    /// The pose this far through the run: 0 a glass just turned over, 1 the
    /// one the app icon is drawn in.
    static func pose(at run: CGFloat) -> Pose {
        let run = min(max(run, 0), 1)
        let risen = max(run - landing, 0) / (1 - landing)

        // The surface does not move until the funnel is dug, which is why this
        // reads the table from `crater` rather than from nothing.
        let surface: CGFloat
        if run <= crater {
            surface = roof
        } else {
            let step = (run - crater) / (1 - crater) * CGFloat(levels.count - 1)
            let stop = min(Int(step), levels.count - 2)
            surface = levels[stop]
                + (levels[stop + 1] - levels[stop]) * (step - CGFloat(stop))
        }

        return Pose(
            level: surface,
            dish: dish * min(run / crater, 1),
            heap: heap * risen,
            front: run < landing ? front(at: run) : base - heap * risen
        )
    }

    /// How far the falling sand has got, in the moment before any of it has
    /// landed and the chamber below is genuinely empty.
    ///
    /// Solved rather than eased, out of the same free fall the column's width
    /// comes from: a stream that is speeding up holds sand in proportion to the
    /// square root of how far it has fallen, so inverting that puts the front
    /// at the *square* of how much has left the throat.
    static func front(at run: CGFloat) -> CGFloat {
        let slowing = ease(to: base)
        let whole = (1 + (base - neckBelow) / slowing).squareRoot()
        let reached = 1 + (run / landing) * (whole - 1)
        return neckBelow + slowing * (reached * reached - 1)
    }

    /// How far out from the middle the sand starts, inside the funnel it has
    /// drained. Sand draining through a hole makes one; a flat top is a photo
    /// of an hourglass nobody has turned over.
    ///
    /// The first line is not a tidying-up. At the very start the funnel has no
    /// depth at all, and the division that follows would be zero by zero — one
    /// `nan` point is a path SwiftUI draws nothing whatever from.
    static func funnel(_ y: CGFloat, _ pose: Pose) -> CGFloat {
        if y <= pose.level { return inside(y) }
        guard pose.dish > 0 else { return 0 }
        let gone = (y - pose.level) / pose.dish
        if gone >= 1 { return 0 }
        return min(inside(pose.level) * (1 - gone).squareRoot(), inside(y))
    }

    /// Half the width of the falling sand, this far below the throat.
    ///
    /// It leaves at the throat's own width and thins, and how fast it thins is
    /// not a taste: the same sand per second through a column going faster is
    /// a column narrower by the fourth root.
    ///
    /// Drawn down to the front, which is not always where the pour is fitted
    /// to land. For the two frames before the first grain arrives they are
    /// different, and the difference is the whole of what those frames say.
    static func falling(_ y: CGFloat, _ pose: Pose) -> CGFloat {
        guard y >= neckBelow, y <= pose.front else { return 0 }
        return throat * pow(1 + (y - neckBelow) / ease(to: base - pose.heap), -0.25)
    }

    /// The one constant in the pour, fitted so the column arrives at the heap
    /// at `fall` however tall the heap has grown.
    static func ease(to apex: CGFloat) -> CGFloat {
        (apex - neckBelow) / (pow(throat / (fall / 2), 4) - 1)
    }

    /// Half the width of the heap at this height. Straight-sided with the point
    /// knocked off it, which is what sand landing on sand does.
    ///
    /// The clamp is not belt and braces. `pow` of a negative base with a
    /// fractional exponent is not a small number, it is `nan`, and one `nan`
    /// point is a path SwiftUI draws nothing at all from — so the arithmetic
    /// that says the top of the heap is exactly at the top of the heap has to
    /// be allowed to be a hair either side of it.
    static func heaped(_ y: CGFloat, _ pose: Pose) -> CGFloat {
        guard pose.heap > 0, y >= base - pose.heap, y <= base else { return 0 }
        return min(
            inside(base) * pow(max(1 - (base - y) / pose.heap, 0), 1 / pile), inside(y))
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
/// Small in three of the four places it appears. In the row and the panel this
/// is the app signing its name rather than a logo somebody has to look at, and
/// at eighteen points the funnel and the falling sand are a pixel or two each
/// and mostly wash out — which is the right way for them to go. What is left is
/// a glass with an empty top and a heap in the bottom, which was the whole
/// sentence anyway.
///
/// The opening is the exception, and it earns it by moving: see `run`.
struct Hourglass: View {
    /// How tall the glass is. Everything else follows from it.
    var height: CGFloat = 18

    /// How far through its run the sand is, from 0 — a glass just turned over,
    /// brim full, nothing fallen — to 1, which is the pose the app icon is
    /// drawn in.
    ///
    /// The default is 1 because everywhere but the opening this is a mark and a
    /// mark does not move. The opening drives it from a clock, and what that
    /// buys is the one thing a still hourglass cannot say: it is *running*, and
    /// it comes to rest on the picture that is already on the home screen.
    var run: CGFloat = 1

    var body: some View {
        let pose = Sandglass.pose(at: run)

        ZStack {
            // Stacked and then faded together rather than each faded on its
            // own: the falling sand touches both the sand above it and the heap
            // below, and three translucent fills over one another would draw
            // two dark seams across the one place the mark is trying to say
            // something.
            ZStack {
                Sand(part: .remaining, pose: pose)
                Sand(part: .falling, pose: pose)
                Sand(part: .fallen, pose: pose)
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
        var pose: Sandglass.Pose

        func path(in box: CGRect) -> Path {
            let funnel = { Sandglass.funnel($0, pose) }
            let falling = { Sandglass.falling($0, pose) }
            let heaped = { Sandglass.heaped($0, pose) }

            var path = Path()
            switch part {
            case .remaining:
                let level = pose.level
                let neck = Sandglass.neckBelow
                var sand = Sandglass.wall(
                    from: level, to: neck, -1, Sandglass.inside, in: box)
                sand += Sandglass.wall(
                    from: neck, to: level, 1, Sandglass.inside, in: box)
                sand += Sandglass.wall(
                    from: level, to: level + pose.dish, 1, funnel, in: box)
                sand += Sandglass.wall(
                    from: level + pose.dish, to: level, -1, funnel, in: box)
                path.addLines(sand)
            case .falling:
                let front = pose.front
                var stream = Sandglass.wall(
                    from: Sandglass.neckBelow, to: front, 1, falling, in: box)
                stream += Sandglass.wall(
                    from: front, to: Sandglass.neckBelow, -1, falling, in: box)
                path.addLines(stream)
            case .fallen:
                let apex = Sandglass.base - pose.heap
                var heap = Sandglass.wall(
                    from: apex, to: Sandglass.base, 1, heaped, in: box)
                heap += Sandglass.wall(
                    from: Sandglass.base, to: apex, -1, heaped, in: box)
                path.addLines(heap)
            }
            path.closeSubpath()
            return path
        }
    }
}
