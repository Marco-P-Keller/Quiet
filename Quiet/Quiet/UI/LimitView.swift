import SwiftUI

/// Changing the number.
///
/// The screen's real job is to say, before anything is committed, exactly what
/// the request will do — including when it will do it, and when the next one
/// would be possible. It gets that description by asking the same rule the
/// button runs, so the two can never disagree.
@MainActor
struct LimitView: View {
    let session: QuietSession
    var onFinish: () -> Void

    @State private var minutes: Int

    private static let choices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

    init(session: QuietSession, onFinish: @escaping () -> Void) {
        self.session = session
        self.onFinish = onFinish
        _minutes = State(initialValue: session.limit.pending?.minutes ?? session.limit.minutes)
    }

    var body: some View {
        // Same shape as setup: centred in the space above the button when it
        // fits, scrolling when the reader's text size says it should not.
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Less takes effect at once. More starts the next day, and only once a week.")
                        .font(.quietNote)
                        .foregroundStyle(Paper.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("Minutes a day", selection: $minutes) {
                        ForEach(options, id: \.self) { value in
                            Text(Phrase.minutes(value))
                                .font(.quietChoice)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180)
                    .padding(.vertical, 8)

                    Text(explanation)
                        .font(.quietBody)
                        .fixedSize(horizontal: false, vertical: true)
                        // Held open so that the button does not walk up and down
                        // the screen as the wheel turns.
                        .frame(minHeight: 74, alignment: .top)
                        .accessibilityLabel(explanation)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            QuietButton(title: buttonTitle, isEnabled: isAllowed, action: commit)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(Paper.page)
        }
        .quietPage()
        .navigationTitle("Daily limit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Paper.page, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    /// The standard choices, plus whatever is currently set, so the wheel always
    /// contains the number it starts on.
    private var options: [Int] {
        var values = Set(Self.choices)
        values.insert(session.limit.minutes)
        if let pending = session.limit.pending { values.insert(pending.minutes) }
        return values.sorted()
    }

    private var outcome: Result<(state: LimitState, change: LimitChange), LimitRefusal> {
        session.preview(minutes)
    }

    private var isAllowed: Bool {
        if case .success = outcome { return true }
        return false
    }

    private var explanation: String {
        switch outcome {
        case let .success((state, change)):
            return describe(change, resulting: state)
        case .failure(.unchanged):
            return "This is your limit."
        case let .failure(.tooSoon(next)):
            return "You raised your limit less than a week ago. You can ask for more again \(Phrase.day(next, relativeTo: session.today))."
        case .failure(.clockRewound):
            return "The date on this phone is behind where Quiet last saw it. Until it catches up, the limit can go down but not up."
        case let .failure(.outOfRange(range)):
            return "Quiet works between \(range.lowerBound) and \(range.upperBound) minutes a day."
        }
    }

    private func describe(_ change: LimitChange, resulting state: LimitState) -> String {
        switch change {
        case .now:
            let lead = minutes == session.limit.minutes
                ? "Cancels the increase you asked for."
                : "Takes effect now."
            if session.ledger.isSpent(limitMinutes: minutes) {
                return lead + " You have already used more than that today, so today ends here."
            }
            return lead
        case let .on(day, _):
            var sentence = "Starts \(Phrase.day(day, relativeTo: session.today)). Today stays at \(Phrase.minutes(session.limit.minutes))."
            if let next = LimitPolicy.nextIncreaseDay(state, today: session.today) {
                sentence += " You can ask for more again \(Phrase.day(next, relativeTo: session.today))."
            }
            return sentence
        }
    }

    /// "Ask for" rather than "Set" when the number will not take effect today.
    /// The button should not promise something the rule will not deliver.
    private var buttonTitle: String {
        if case let .success((_, change)) = outcome, case .on = change {
            return "Ask for \(Phrase.minutes(minutes)) a day"
        }
        return "Set \(Phrase.minutes(minutes)) a day"
    }

    private func commit() {
        guard case let .success(change) = session.requestLimit(minutes) else { return }
        switch change {
        case let .now(value):
            session.show("Your limit is now \(Phrase.minutes(value)) a day.")
        case let .on(day, value):
            session.show("\(Phrase.minutes(value)) a day, starting \(Phrase.day(day, relativeTo: session.today)).")
        }
        onFinish()
    }
}
