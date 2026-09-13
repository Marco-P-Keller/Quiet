import Foundation

/// How tall the chart has to be, and which of its reference lines fit on it.
///
/// Pulled out of the view because it is a rule rather than a drawing, and
/// because the way it was first written was wrong in a way only a photograph
/// found. The scale used to be *whichever is tallest* — the busiest day, the
/// limit, or the day somebody started from — on the argument that measuring a
/// good week against the day you came from is what makes it read as a good
/// week. That is true, and it holds only while the numbers are within sight of
/// each other.
///
/// Somebody who came from five hours a day and now spends thirteen minutes
/// broke it. The top line was twenty-three times the tallest column, so every
/// day of the week was drawn six points high and the chart was a rectangle of
/// blank with two dashes in it — a picture of nothing, on the one screen whose
/// whole job is to show something.
///
/// So the days set the scale, and a reference joins them only if it is within
/// reach. When it is not it is simply left off: the sentence above the chart
/// already makes that comparison, in words that do not need a hundred and fifty
/// points of empty space to be true.
enum ChartScale {
    /// How far above the busiest day a line may sit and still be worth drawing.
    ///
    /// Two and a half, which is the worst case the scale will accept and puts
    /// the busiest column at a little over a third of the chart. Below that a
    /// bar stops looking like a measurement and starts looking like a mistake,
    /// which is the whole complaint this number exists to answer.
    ///
    /// It is not one. A reference exactly at the top of the data would mean the
    /// limit vanished from the chart on every day somebody came in under it —
    /// which is most days, and is the good news. Some room above the tallest
    /// column is what keeps the line that matters on the page.
    static let crowding: TimeInterval = 2.5

    /// The smallest the data is allowed to be before it stops setting the
    /// scale, so that a single five-second visit does not make a chart out of
    /// nothing.
    static let leastBusy: TimeInterval = 60

    /// A twelfth of headroom over whatever is tallest, so that the tallest
    /// thing is a mark *inside* the chart rather than one pressed flat against
    /// its top edge, where it stops reading as a mark on a scale at all.
    static let headroom: TimeInterval = 13.0 / 12.0

    /// The busiest day on the chart, floored.
    static func busiest(_ days: [TimeInterval]) -> TimeInterval {
        max(leastBusy, days.max() ?? 0)
    }

    /// Whether a reference can be drawn without flattening the days it is there
    /// to be read against.
    static func shows(_ reference: TimeInterval, whenBusiestIs busiest: TimeInterval) -> Bool {
        reference > 0 && reference <= busiest * crowding
    }

    /// The top of the scale: the days, plus whichever references can be shown
    /// beside them, plus the headroom.
    static func ceiling(busiest: TimeInterval, references: [TimeInterval]) -> TimeInterval {
        let top = references
            .filter { shows($0, whenBusiestIs: busiest) }
            .reduce(busiest, max)
        return top * headroom
    }
}
