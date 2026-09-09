import SwiftUI

/// The two things somebody opens this for: how much of today is left, and what
/// the days behind them came to.
///
/// It held everything for a long time, and short was not the same as legible.
/// Nine sections ran down it, every one cut off from the next by the same rule
/// at the same weight, every line of type on it set in the same ink — the name
/// of a group, the label on a switch, the row that changes the number the whole
/// app is about. Nine equal things in a row is a list, and a list cannot be
/// skimmed. A shape was given to it and it helped: running heads in small
/// tracked capitals, rules only where two rows of one table meet, and anything
/// you press made to look pressed. See `PanelParts`, where all three live.
///
/// What the shape could not fix is that eight of those nine were decisions made
/// once and then lived with — the wait, what the feed contains, what the app
/// says and when, the shape of the row, the way out — standing in front of the
/// two figures that change every day. That cost a reader something on every
/// visit in order to save a tap on the rare occasion any of it moved.
///
/// So the eight went one door further in, behind the gear in the corner, and
/// this screen is now the answer to "how am I doing" rather than a table of
/// contents. See `SettingsView`, which is the same screen it always was.
///
/// Not one sentence was rewritten to do any of it.
@MainActor
struct PanelView: View {
    let session: QuietSession
    let surface: WebSurface
    let preferences: Preferences
    var onDismiss: () -> Void

    @State private var isChangingLimit = false
    @State private var isChangingSettings = false
    /// Which stretch of days the chart is showing, and whether the number it
    /// is all measured against is open for correction.
    @State private var recordLength = 7
    /// The day being asked about on the chart, if one is. Cleared whenever the
    /// chart changes underneath it, because a day picked out of a week is not
    /// necessarily on the month.
    @State private var selectedDay: DayKey?


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    today

                    Cluster("The days behind you") { theRecord }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .quietPage()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Quiet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Done on the left and the rest on the right, which is the
                // wrong way round for a sheet and the right way round for this
                // one. The trailing corner is where a thumb lands, and what
                // belongs under a thumb on a screen you opened to read two
                // numbers is the way further in — not the way out, which is
                // also the whole bottom edge of the sheet and a downward drag
                // from anywhere on it.
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isChangingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel(Text("Settings"))
                    }
                    .accessibilityIdentifier("panel.settings")
                }
            }
            .navigationDestination(isPresented: $isChangingLimit) {
                LimitView(session: session) {
                    // Leave the stack where it started, so that opening the panel
                    // again lands on the panel rather than halfway into a screen
                    // nobody asked for.
                    isChangingLimit = false
                    onDismiss()
                }
            }
            .navigationDestination(isPresented: $isChangingSettings) {
                SettingsView(
                    session: session,
                    surface: surface,
                    preferences: preferences,
                    onDismiss: {
                        isChangingSettings = false
                        onDismiss()
                    }
                )
            }
            .toolbarBackground(Paper.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(Paper.page)
        .onAppear(perform: openLimitIfRehearsing)
    }

    /// Nothing at all, except when a screenshot is being taken of one of the
    /// screens behind this one. See `Rehearsal`, which does not exist outside a
    /// debug build.
    private func openLimitIfRehearsing() {
        #if DEBUG
        if Rehearsal.opensLimit { isChangingLimit = true }
        if Rehearsal.opensSettings { isChangingSettings = true }
        #endif
    }

    // MARK: - Today

    /// The top of the page, and the only group that needs no head: the headline
    /// is one.
    ///
    /// Under it, the two rows that leave this screen, set as a short table with
    /// a rule above, between and below. That the limit is the most-used control
    /// in the app was true before and invisible before — it hung under a
    /// paragraph with two dozen points of nothing over it and looked like a
    /// footnote to a sentence. A table is a table; you can see that it is
    /// something to press.
    private var today: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headline)
                .font(.quietTitle)
                .fixedSize(horizontal: false, vertical: true)

            Text(subhead)
                .font(.quietNote)
                .foregroundStyle(Paper.inkSoft)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                Hairline()

                Step(
                    "Daily limit",
                    value: Phrase.minutes(session.limit.minutes)
                ) {
                    isChangingLimit = true
                }

                Hairline()
            }
            .padding(.top, 20)

            if let pending = session.limit.pending {
                Text("\(Phrase.minutes(pending.minutes)) from \(Phrase.day(pending.effective, relativeTo: session.today)).")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 12)
            }

            if session.isClockRewound {
                Text("The date on this phone is behind where Quiet last saw it. The limit can be lowered, but not raised, until it catches up.")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            } else if session.isClockAdvanced {
                // The other half of the same sentence. It reads as an accusation
                // if it is written as one, so it is not: two clocks disagree,
                // and the app says which one it is going by.
                Text("The date on this phone is ahead of Instagram's, so Quiet is going by Instagram's. The limit can be lowered, but not raised, until the two agree.")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headline: String {
        switch session.screen {
        case .spent: return String(localized: "No time left today.")
        default: return String(localized: "\(Phrase.remaining(session.remaining)) left today.")
        }
    }

    private var subhead: String {
        String(localized: "Resets at \(Phrase.clockTime(session.resetsAt)).")
    }

    // MARK: - The days behind you

    /// The one place Quiet argues with its own past.
    ///
    /// The ledger's note still says why there was never a chart here — *a
    /// record of how much you scrolled is one more thing to check* — and that
    /// argument has not stopped being true. What answers it is that the app now
    /// asks, on its first screen, how much Instagram a day was before any of
    /// this. A number a person hands over is a promise, and the days behind them
    /// are the only thing that can answer it.
    ///
    /// It sits here, first, in the open. It spent a version behind a row and a
    /// tap on the argument that a running total of what the app has saved you
    /// has no business sitting where somebody comes to negotiate their limit —
    /// which is a real risk and was the wrong call anyway: a screen nobody finds
    /// answers nobody's promise. There is still no streak and nothing to break;
    /// the figure is a total, so it only ever goes one way, and no notification
    /// or badge anywhere points at this.
    private var theRecord: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            if session.baseline > 0 {
                saved
            } else {
                // The upgrade path, and the one state a screenshot found. Setup
                // asks for this number; anybody who set Quiet up before it did
                // has never been asked, and hiding the whole comparison leaves
                // them a chart with no explanation of what the missing half is.
                Note("Quiet does not know what your day was before this, so there is nothing yet to measure against. The gear above is where to say.")
            }

            chart
                // The prose above ends in a full stop and the chart begins with
                // two pills, and at the spacing everything else in this cluster
                // uses they read as one paragraph with buttons in it.
                .padding(.top, 8)

        }
    }

    /// Completed days only.
    ///
    /// A total that counted today would fall while somebody watched it, because
    /// every minute spent is a minute of it unspent. A figure that goes
    /// backwards as you read it is a scoreboard, which is the one thing this
    /// must not be.
    ///
    /// Two lines and no more. This carried today's standing and the caveat about
    /// which days are counted as well; both were true and neither belonged here.
    /// Today is a column on the chart directly below, which you can ask by
    /// tapping it, and a caveat is a thing you read once — it is under the gear
    /// now, with the rest of the prose.
    private var saved: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A heading rather than the display face this had on a screen of
            // its own. Here it is a section of a page whose own headline sits
            // three lines above it, and two serif numbers at the same size
            // compete for the same job.
            Text(Phrase.span(session.savedSoFar))
                .font(.quietHeading)
                .fixedSize(horizontal: false, vertical: true)

            Text("less than the \(Phrase.minutes(session.baseline)) a day you started from.")
                .font(.quietNote)
                .foregroundStyle(Paper.inkSoft)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForEach(Self.recordLengths, id: \.self) { days in
                    span(days)
                }
                Spacer()
            }

            Bars(
                run: session.record.run(endingOn: session.today, length: recordLength),
                today: session.today,
                limitMinutes: session.limit.minutes,
                baselineMinutes: session.baseline,
                showsEveryLabel: recordLength <= 7,
                selected: $selectedDay
            )

            legend
        }
    }

    private func span(_ days: Int) -> some View {
        let chosen = recordLength == days
        return Button {
            recordLength = days
            selectedDay = nil
        } label: {
            Text(Phrase.days(days))
                .font(.quietBody)
                .foregroundStyle(chosen ? Paper.page : Paper.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(chosen ? Paper.ink : Color.clear))
                .overlay(Capsule().strokeBorder(Paper.rule, lineWidth: chosen ? 0 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// One line, holding either the whole window or the one day being asked
    /// about.
    ///
    /// Two lines — a summary that stays and an answer that appears under it —
    /// would move everything below the chart down by a line on every tap, which
    /// is a page that flinches when you question it. The sentence naming the two
    /// dashed rules went under the gear with the rest of the prose: it is read
    /// once, and it was a third paragraph on a screen meant to be a number and
    /// a picture.
    private var legend: some View {
        let window = DayKey(ordinal: session.today.ordinal - recordLength + 1)...session.today
        return Text(selectedDay.map(dayLine) ?? String(
            localized: "\(Phrase.span(session.record.spent(in: window))) over \(Phrase.days(recordLength)) — Quiet was open on \(session.record.days(in: window).count) of them."
        ))
            .font(.quietSmall)
            .foregroundStyle(selectedDay == nil ? Paper.inkSoft : Paper.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// What one day came to, for the line under the chart.
    ///
    /// Named in full — the weekday and the date — because the axis has room
    /// for one letter and one letter is not an answer to "which Tuesday".
    private func dayLine(_ day: DayKey) -> String {
        let named = day.start().formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let seconds = session.record.seconds(on: day) else {
            return String(localized: "\(named): Quiet was not opened.")
        }
        if day == session.today {
            return String(localized: "\(named): \(Phrase.span(seconds)) so far.")
        }
        return String(localized: "\(named): \(Phrase.span(seconds)).")
    }

    /// A week and a month, which are the two lengths anybody thinks in.
    private static let recordLengths = [7, 30]


}

enum Build {
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "Version \(version) (\(build))")
    }
}
