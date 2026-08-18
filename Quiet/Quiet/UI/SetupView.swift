import SwiftUI

/// First run. Two screens: what this is, and how much time you want.
///
/// Nothing is asked for that Quiet does not need. No account, no email, no
/// notifications, no permission prompts of any kind. The only question is the
/// one the app exists to ask.
struct SetupView: View {
    var onFinish: (Int) -> Void

    @State private var step = Step.what
    @State private var minutes = 20

    private enum Step { case what, howMuch }

    /// Round numbers a person would actually say out loud.
    private static let choices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .what: what
            case .howMuch: howMuch
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .quietPage()
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var what: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            Text("Instagram,\nminus the parts\nthat keep you there.")
                .font(.quietTitle(32))
                .lineSpacing(6)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 14) {
                Line("No Reels. No Explore. No accounts suggested between your friends.")
                Line("Your feed, your stories, your messages, your profile. Everything else works the way it always did.")
                Line("You sign in on Instagram's own page. Your password never touches Quiet.")
                Line("Quiet runs on Instagram's mobile site, so pages load a beat slower and a few things are missing.")
            }

            Spacer(minLength: 24)

            QuietButton(title: "Continue") { step = .howMuch }
        }
    }

    private var howMuch: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 16)

            Text("How much Instagram\ndo you want in a day?")
                .font(.quietTitle(28))
                .lineSpacing(5)
                .padding(.bottom, 4)

            Picker("Minutes a day", selection: $minutes) {
                ForEach(Self.choices, id: \.self) { value in
                    Text(Phrase.minutes(value))
                        .font(.quietTitle(22))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 12) {
                Line("You can ask for less whenever you like. It takes effect at once.")
                Line("You can ask for more once a week, and it starts the next day — never in the moment you want five more minutes.")
                Line("Your limit is kept outside the app. Deleting Quiet and installing it again does not reset it.")
            }
            .padding(.top, 8)

            Spacer(minLength: 20)

            QuietButton(title: "Set \(Phrase.minutes(minutes)) a day") {
                onFinish(minutes)
            }
        }
    }

    /// One sentence, set the way the whole app sets sentences.
    private struct Line: View {
        let text: String

        init(_ text: String) { self.text = text }

        var body: some View {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SetupView { _ in }
}
