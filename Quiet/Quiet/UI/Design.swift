import SwiftUI
import UIKit

/// Quiet's own surfaces look nothing like the site it shows.
///
/// Instagram is bright, dense and full of things to press. The three screens
/// Quiet owns — setup, the panel, the curtain — are paper: warm, plain, mostly
/// empty, one thing to read at a time. The difference is the point. When the
/// curtain comes down you should be able to feel that you have left.
enum Paper {
    /// Background. Warm off-white by day, warm near-black by night; never pure
    /// white or pure black, both of which glare.
    static let page = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.071, green: 0.067, blue: 0.063, alpha: 1)
            : UIColor(red: 0.969, green: 0.957, blue: 0.937, alpha: 1)
    })

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
/// A long press that does nothing until a sheet appears feels broken, because
/// you cannot tell whether you held it long enough. One soft tap at the moment
/// it takes is what every long press on iOS does, and the reason it feels like
/// a control rather than a guess.
@MainActor
enum Feedback {
    static func gestureRecognised() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

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
