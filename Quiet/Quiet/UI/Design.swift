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

extension Font {
    /// The one voice Quiet speaks in. A serif, because the app's few sentences
    /// are meant to be read rather than scanned, and because nothing else on the
    /// phone looks like it.
    static func quietTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

extension View {
    /// The standard page: paper to the edges, generous margins, text that never
    /// runs the full width of a phone.
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
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Paper.ink.opacity(isEnabled ? 1 : 0.25))
                .foregroundStyle(Paper.page)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

/// Minutes, said the way a person would say them.
enum Phrase {
    static func minutes(_ count: Int) -> String {
        count == 1 ? "1 minute" : "\(count) minutes"
    }

    /// Rounds up, so "0 minutes left" never sits on screen while time is still
    /// running.
    static func remaining(_ seconds: TimeInterval) -> String {
        minutes(max(0, Int(ceil(seconds / 60))))
    }

    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "on Tuesday" for the coming week, a date after that.
    static func day(_ day: DayKey, relativeTo today: DayKey, calendar: Calendar = .current) -> String {
        let date = day.start(calendar: calendar)
        let distance = today.days(to: day)
        if distance <= 0 { return "today" }
        if distance == 1 { return "tomorrow" }
        // Exactly a week out gets a date, not a weekday: "on Tuesday" is the
        // same word as today, and would read as the wrong Tuesday.
        if distance > 1 && distance < 7 {
            return "on " + date.formatted(.dateTime.weekday(.wide))
        }
        return "on " + date.formatted(.dateTime.day().month(.wide))
    }
}
