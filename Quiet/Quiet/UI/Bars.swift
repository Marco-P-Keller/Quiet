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

    /// Tall enough that a difference of ten minutes is visible on a day of
    /// forty, short enough that the whole screen still fits on a small phone.
    private static let height: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                mark(at: TimeInterval(limitMinutes) * 60)
                if baselineMinutes > 0 {
                    mark(at: TimeInterval(baselineMinutes) * 60)
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
                // A rounded rectangle rather than a capsule, and the first
                // draft got that wrong in a way a photograph made obvious: a
                // capsule shorter than it is wide is a circle, so every quiet
                // day came out as a fat blob taller than the minutes it stood
                // for, and the chart overstated exactly the days it should have
                // been calmest about.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(entry.day == today ? Paper.ink.opacity(0.35) : Paper.ink.opacity(0.75))
                    // Nothing at all for a day Quiet was not opened on, and a
                    // hairline for a day it was opened on and barely used. The
                    // first draft drew both as a faint hairline, and on the
                    // month a fortnight of them lined up into what looked
                    // exactly like a second dashed rule — one visual language
                    // saying two different things a few pixels apart. An empty
                    // slot cannot be misread: it is the one mark that means
                    // *nothing was recorded*, and the sentence underneath says
                    // how many of them there were.
                    .frame(height: height(of: entry.seconds))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(label(for: entry))
            }
        }
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
                Text(shows(entry.day) ? name(of: entry.day) : " ")
                    .font(.quietFine)
                    .foregroundStyle(Paper.inkSoft)
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

    /// The tallest thing on the chart, which is whichever is larger: the
    /// busiest day, or the old day being compared against.
    ///
    /// Including the baseline in the scale is the whole visual argument. Scaled
    /// to the busiest day alone, a good week fills the frame and looks like a
    /// lot; scaled against the day somebody started from, the same week is a row
    /// of short columns under a line, which is what it is.
    private var ceiling: TimeInterval {
        let busiest = run.compactMap(\.seconds).max() ?? 0
        let lines = max(TimeInterval(limitMinutes), TimeInterval(baselineMinutes)) * 60
        // A twelfth of headroom, so that whichever of the three is tallest is a
        // line inside the chart rather than one pressed flat against its top
        // edge, where it stops reading as a mark on a scale.
        return max(60, busiest, lines) * 13 / 12
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
