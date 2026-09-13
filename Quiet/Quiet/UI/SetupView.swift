import SwiftUI

/// First run. Three screens: what this is, the day you are having, and the day
/// you want.
///
/// Nothing is asked for that Quiet does not need. No account, no email, no
/// notifications, no permission prompts of any kind.
///
/// The middle screen is the one that had to justify itself, because for a long
/// time there was only one question here and that was the point. What earns it
/// is that it is the only figure in this app that cannot be measured: Quiet can
/// see its own screen and nothing else on the phone — not the real Instagram
/// app, not Screen Time, nothing. So either somebody says what their day used
/// to be, once, on the one screen where they are already thinking about it, or
/// every sentence the app might later say about what it has done for them is
/// unavailable. It restricts nothing. It is one end of a comparison.
///
/// It is also asked *before* the limit rather than after, which is the whole of
/// its usefulness: a number typed in ignorance of your own day is a guess, and
/// the second wheel opens at half of the first.
struct SetupView: View {
    /// The day being had, and the day wanted.
    var onFinish: (Int, Int) -> Void

    @State private var step = Step.what
    @State private var baseline = 60
    @State private var minutes = 20
    /// Whether the limit wheel has been opened at half the baseline yet. Once
    /// only: going back to change the old day should not throw away a limit
    /// that has since been chosen deliberately.
    @State private var suggested = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step { case what, now, howMuch }

    /// Round numbers a person would actually say out loud.
    private static let choices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

    /// The same, carried further up. A limit above four hours is not a limit,
    /// but a *day* above four hours is just somebody's Tuesday, and a wheel
    /// that stops short of the truth collects a wrong answer rather than no
    /// answer.
    private static let daysHad = [10, 15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480]

    /// Where the limit wheel opens, given the day somebody says they have.
    ///
    /// Half, rounded down to a number on the wheel. Not a target and not
    /// advice — the wheel moves freely in both directions — but a starting
    /// point that is about *their* day rather than about twenty minutes, which
    /// is a number that means nothing to somebody who has just said four hours.
    static func suggestion(halfOf baseline: Int) -> Int {
        choices.last { $0 <= baseline / 2 } ?? choices[0]
    }

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
                    case .now: dayYouHave
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
                Line("No Reels. No Explore.")
                // The one-star review this app was always going to get, headed
                // off in one sentence: somebody who opens it expecting all of
                // Instagram and finds Reels missing has not found a broken app,
                // and there is no way for them to know that unless it is said
                // here. Nobody reads a store listing.
                Line("Those are gone on purpose, not missing. Tapping a Reel a friend sends you will say so rather than open it.")
                // Said here because this list is the app's own description of
                // itself, and it used to promise something the app no longer
                // does. The suggested posts are shown; taking them out is a
                // switch, and a switch nobody knows about is a switch nobody
                // has.
                Line("The posts Instagram suggests between your friends are still there. A switch in Quiet's settings takes them out.")
                Line("Your feed, your stories, your messages, your profile. Everything else works the way it always did.")
                Line("You sign in on Instagram's own page. Your password never touches Quiet.")
                Line("Quiet runs on Instagram's mobile site, so pages load a beat slower and a few things are missing.")
            }
        }
    }

    private var dayYouHave: some View {
        VStack(alignment: .leading, spacing: 0) {
            back(to: .what)

            Text("How much Instagram\ndo you have in a day now?")
                .font(.quietHeading)
                .lineSpacing(5)

            Picker("Minutes a day now", selection: $baseline) {
                ForEach(Self.daysHad, id: \.self) { value in
                    Text(Phrase.minutes(value))
                        .font(.quietChoice)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                Line("A rough answer is fine. Your phone's Screen Time knows, if you would rather look.")
                Line("This is not a limit and it does not restrict anything. It is the number the days behind you get measured against.")
                Line("Quiet cannot see this for itself. It only ever sees its own screen — not the Instagram app, not any other app on this phone.")
            }
        }
    }

    private var howMuch: some View {
        VStack(alignment: .leading, spacing: 0) {
            back(to: .now)

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
            // See LimitView: a wheel's rows are a fixed height, so the numbers
            // collide past the largest ordinary text size. The choice is
            // repeated at full size on the button underneath.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                // Said as arithmetic rather than as a promise. "A week" is the
                // unit the difference first becomes legible in, and it is a
                // subtraction of two numbers on this screen rather than a claim
                // about anybody's willpower.
                if baseline > minutes {
                    Line("\(Phrase.span(TimeInterval(baseline - minutes) * 60 * 7)) a week fewer than the day you just described.")
                }
                Line("You can ask for less whenever you like. It takes effect at once.")
                Line("You can ask for more once a week, and it starts the next day — never in the moment you want five more minutes.")
                Line("Your limit is kept outside the app. Deleting Quiet and installing it again does not reset it.")
            }
        }
    }

    private func back(to destination: Step) -> some View {
        Button {
            step = destination
        } label: {
            Label("Back", systemImage: "chevron.left")
                .font(.quietSmall)
                .foregroundStyle(Paper.inkSoft)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 20)
    }

    private var actionTitle: String {
        switch step {
        case .what: return String(localized: "Continue")
        case .now: return String(localized: "Continue")
        case .howMuch: return String(localized: "Set \(Phrase.minutes(minutes)) a day")
        }
    }

    private func advance() {
        switch step {
        case .what:
            step = .now
        case .now:
            if !suggested {
                minutes = Self.suggestion(halfOf: baseline)
                suggested = true
            }
            step = .howMuch
        case .howMuch:
            onFinish(baseline, minutes)
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
    SetupView { _, _ in }
}
