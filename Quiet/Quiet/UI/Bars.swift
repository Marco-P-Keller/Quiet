import SwiftUI

/// The chart itself.
///
/// Drawn by hand rather than with a charting framework, for the same reason
/// every other surface in this app is: the frameworks are built to make data
/// look exciting, and the whole argument of these screens is that Instagram is
/// the exciting thing and Quiet is the paper. One ink, one weight of line, no
/// axis furniture, no gridlines, no gradient.
struct Bars: View {
    let run: [(day: DayKey, seconds: TimeInterval?)]
    let today: DayKey
    let limitMinutes: Int
    let baselineMinutes: Int
    let showsEveryLabel: Bool

    /// The day being asked about, if one is.
    ///
    /// Held by whoever draws the chart rather than in here, because the answer
    /// is a sentence and the sentence belongs under the chart with the other
    /// sentences — not floating over a column in a callout of its own. Every
    /// other figure on this screen is prose in the same ink; a tooltip would be
    /// the one piece of chart furniture in an app that has none.
    @Binding var selected: DayKey?

    /// Tall enough that a difference of ten minutes is visible on a day of
    /// forty, short enough that the whole screen still fits on a small phone.
    private static let height: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                // Only the lines that are on the scale. One that is not would
                // have to be drawn pressed against the top edge, which says
                // "just above your busiest day" about a number that may be
                // twenty times it — a chart lying to keep a line.
                ForEach(references.filter(isOnScale), id: \.self) { reference in
                    mark(at: reference)
                }
                columns
            }
            .frame(height: Self.height)

            labels
        }
    }

    private var columns: some View {
        HStack(alignment: .bottom, spacing: run.count > 14 ? 2 : 6) {
            ForEach(run, id: \.day.ordinal) { entry in
                // The whole column takes the tap, not the bar.
                //
                // A quiet day is two points tall and a day Quiet never saw is
                // nothing at all, so a target the shape of the drawing would be
                // untappable exactly where somebody most wants to ask — and on
                // the month there are thirty of them, ten points wide. The
                // clear rectangle behind each bar is the full height of the
                // chart, which is a target the size of a fingertip in the only
                // direction that is scarce.
                ZStack(alignment: .bottom) {
                    Color.clear
                    column(entry)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tapping the day already being asked about puts the
                    // question away, so there is a way out that is not "find
                    // some other part of the screen to press".
                    selected = selected == entry.day ? nil : entry.day
                }
                .accessibilityElement()
                .accessibilityLabel(label(for: entry))
                .accessibilityAddTraits(selected == entry.day ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func column(_ entry: (day: DayKey, seconds: TimeInterval?)) -> some View {
        // A rounded rectangle rather than a capsule, and the first draft got
        // that wrong in a way a photograph made obvious: a capsule shorter than
        // it is wide is a circle, so every quiet day came out as a fat blob
        // taller than the minutes it stood for, and the chart overstated
        // exactly the days it should have been calmest about.
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(shade(of: entry.day))
            // Nothing at all for a day Quiet was not opened on, and a hairline
            // for a day it was opened on and barely used. The first draft drew
            // both as a faint hairline, and on the month a fortnight of them
            // lined up into what looked exactly like a second dashed rule — one
            // visual language saying two different things a few pixels apart.
            // An empty slot cannot be misread: it is the one mark that means
            // *nothing was recorded*, and the sentence underneath says how many
            // of them there were.
            .frame(height: height(of: entry.seconds))
            .frame(maxWidth: .infinity)
    }

    /// Today is paler because it is not finished; the day being asked about is
    /// the darkest thing on the chart, because that is the whole of what
    /// selection has to say and this app has one ink to say it in.
    private func shade(of day: DayKey) -> Color {
        if selected == day { return Paper.ink }
        if day == today { return Paper.ink.opacity(0.35) }
        return Paper.ink.opacity(selected == nil ? 0.75 : 0.4)
    }

    /// A dashed rule across the chart at a given number of seconds.
    private func mark(at seconds: TimeInterval) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color.clear)
                .frame(height: Self.height * fraction(of: seconds))
                .overlay(alignment: .top) {
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Paper.ink.opacity(0.3))
                        .frame(height: 1)
                }
        }
        .accessibilityHidden(true)
    }

    private var labels: some View {
        HStack(alignment: .top, spacing: run.count > 14 ? 2 : 6) {
            ForEach(run, id: \.day.ordinal) { entry in
                Text(shows(entry.day) || selected == entry.day ? name(of: entry.day) : " ")
                    .font(.quietFine)
                    .foregroundStyle(selected == entry.day ? Paper.ink : Paper.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// Every day on a week; the ends and every seventh on a month, because
    /// thirty labels on a phone is thirty smudges.
    private func shows(_ day: DayKey) -> Bool {
        if showsEveryLabel { return true }
        return (today.ordinal - day.ordinal) % 7 == 0
    }

    /// The two numbers the days are read against, tallest last.
    private var references: [TimeInterval] {
        [TimeInterval(limitMinutes), TimeInterval(baselineMinutes)]
            .filter { $0 > 0 }
            .map { $0 * 60 }
            .sorted()
    }

    private var busiest: TimeInterval {
        ChartScale.busiest(run.compactMap(\.seconds))
    }

    private func isOnScale(_ reference: TimeInterval) -> Bool {
        ChartScale.shows(reference, whenBusiestIs: busiest)
    }

    private var ceiling: TimeInterval {
        ChartScale.ceiling(busiest: busiest, references: references)
    }

    private func fraction(of seconds: TimeInterval) -> CGFloat {
        CGFloat(min(1, max(0, seconds / ceiling)))
    }

    private func height(of seconds: TimeInterval?) -> CGFloat {
        guard let seconds else { return 0 }
        return max(2, Self.height * fraction(of: seconds))
    }

    private func label(for entry: (day: DayKey, seconds: TimeInterval?)) -> Text {
        let date = entry.day.start().formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let seconds = entry.seconds else {
            return Text("\(date): Quiet was not opened.")
        }
        return Text("\(date): \(Phrase.span(seconds)).")
    }

    /// A weekday initial on a week, a date on a month.
    ///
    /// The month used to carry initials too, and a photograph of it settled the
    /// question in one look: labelling every seventh day back from today labels
    /// five days that are all the *same* weekday, so the axis read W W W W W and
    /// said nothing at all.
    private func name(of day: DayKey) -> String {
        showsEveryLabel
            ? day.start().formatted(.dateTime.weekday(.narrow))
            : day.start().formatted(.dateTime.day())
    }

    /// A horizontal rule. `Divider` cannot be dashed, and a `Path` can.
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
