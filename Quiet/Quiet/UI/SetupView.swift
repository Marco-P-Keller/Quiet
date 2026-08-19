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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step { case what, howMuch }

    /// Round numbers a person would actually say out loud.
    private static let choices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

    var body: some View {
        // A scroll view rather than a fixed layout, so that the screen still
        // works at the largest text sizes instead of quietly cropping the
        // sentence that explains what the app does.
        //
        // The geometry reader is what makes the page look composed rather than
        // merely fitted: it gives the text block a minimum height of the space
        // actually available above the button, so a short page sits centred in
        // its own field instead of hugging the top edge above a void. At large
        // text sizes the content outgrows that minimum and simply scrolls.
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case .what: what
                    case .howMuch: howMuch
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            QuietButton(title: actionTitle, action: advance)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(Paper.page)
        }
        .quietPage()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)
    }

    private var what: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Instagram,\nminus the parts\nthat keep you there.")
                .font(.quietDisplay)
                .lineSpacing(6)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 14) {
                Line("No Reels. No Explore. No accounts suggested between your friends.")
                Line("Your feed, your stories, your messages, your profile. Everything else works the way it always did.")
                Line("You sign in on Instagram's own page. Your password never touches Quiet.")
                Line("Quiet runs on Instagram's mobile site, so pages load a beat slower and a few things are missing.")
            }
        }
    }

    private var howMuch: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                step = .what
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)

            Text("How much Instagram\ndo you want in a day?")
                .font(.quietHeading)
                .lineSpacing(5)

            Picker("Minutes a day", selection: $minutes) {
                ForEach(Self.choices, id: \.self) { value in
                    Text(Phrase.minutes(value))
                        .font(.quietChoice)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                Line("You can ask for less whenever you like. It takes effect at once.")
                Line("You can ask for more once a week, and it starts the next day — never in the moment you want five more minutes.")
                Line("Your limit is kept outside the app. Deleting Quiet and installing it again does not reset it.")
            }
        }
    }

    private var actionTitle: String {
        switch step {
        case .what: return String(localized: "Continue")
        case .howMuch: return String(localized: "Set \(Phrase.minutes(minutes)) a day")
        }
    }

    private func advance() {
        switch step {
        case .what: step = .howMuch
        case .howMuch: onFinish(minutes)
        }
    }

    /// One sentence, set the way the whole app sets sentences.
    private struct Line: View {
        let key: LocalizedStringKey

        /// A key rather than a string, so the sentence is translated. `Text` of
        /// a `String` variable is verbatim by design.
        init(_ key: LocalizedStringKey) { self.key = key }

        var body: some View {
            Text(key)
                .font(.quietNote)
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SetupView { _ in }
}
