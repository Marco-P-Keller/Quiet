import SwiftUI

/// Everything Quiet can be told to do, on one screen.
///
/// It is short on purpose. An app with a settings screen you can get lost in has
/// already lost the argument it was built to win.
///
/// Short is not the same as legible, and for a long time this screen was only
/// the first. Nine sections ran down it; every one was cut off from the next by
/// the same rule at the same weight, and every line of type on it — the name of
/// a group, the label on a switch, the row that changes the number the whole app
/// is about — was set in the same seventeen points of the same ink. Nine equal
/// things in a row is a list, and a list cannot be skimmed: there is nothing for
/// the eye to catch on, so finding the one switch you came in for meant reading
/// from the top.
///
/// So the page has a shape now, made of three things and no colour:
///
///   * **Three levels of type instead of one.** A running head says what the
///     next few controls are about; a control is set in body ink; the sentence
///     under it is fine and soft. Small tracked capitals for the heads — on a
///     page this full of prose, it is the one treatment that can never be
///     mistaken for prose.
///   * **Rules where rows meet, air where groups do.** A running head with a
///     generous gap over it parts two groups better than a hairline does, and
///     drawing both is saying it twice. The rules moved to the one place they
///     earn their keep: between two rows of the same short table.
///   * **Things you press look pressed.** The limit and the search were rows
///     with a chevron. The three doors at the foot were bare runs of body text,
///     indistinguishable from the paragraphs around them — "Sign out of
///     Instagram" read as a remark about the app rather than as the button that
///     signs you out. They are all rows now.
///
/// Not one sentence was rewritten to do it, and nothing moved that a reader had
/// learnt the position of except the search, which came up to sit beside the
/// limit: the two places this panel can take you, together, rather than one of
/// them stranded between two rules in the middle of the page.
@MainActor
struct PanelView: View {
    let session: QuietSession
    let surface: WebSurface
    let preferences: Preferences
    var onFindSomeone: () -> Void
    var onDismiss: () -> Void

    @State private var isConfirmingSignOut = false
    @State private var isChangingLimit = false

    /// Why the last request to change the wait was turned down, if it was.
    /// Cleared by the next tap, so it answers the thing that was just pressed
    /// rather than sitting there.
    @State private var waitRefused: String?
    /// Set when the phone declines notifications, so the switch can say why it
    /// slid back rather than just sliding back.
    @State private var appointmentRefused = false
    @State private var isConfirmingForget = false
    @State private var hasCleared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    today

                    Cluster("The wait between increases") { theWait }

                    Cluster("What is in the feed") { suggestions }

                    // Two switches under one head, because they answer the same
                    // question — does the app speak to you, and when. A rule
                    // between them, because they are two answers and not one.
                    Cluster("What Quiet says") {
                        warnings
                        Hairline().padding(.vertical, 4)
                        appointment
                    }

                    Cluster("Your other devices") { otherDevices }

                    Cluster("The row along the bottom") { rowShape }

                    Cluster("Instagram on this phone") { instagramHere }

                    Cluster("The way out") { letGo }

                    // Nothing at all, on almost every launch — head and all.
                    if hasTrouble {
                        Cluster("What is not working") { trouble }
                    }

                    Cluster("About Quiet") { about }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            // Nowhere in Quiet can you drag a short page off its own bottom
            // into the paper behind it. On a phone with large text this list is
            // longer than the glass and scrolls; on a small one at the default
            // size it is not, and without this it springs about anyway.
            .scrollBounceBehavior(.basedOnSize)
            .quietPage()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Quiet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
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
            .toolbarBackground(Paper.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(Paper.page)
        .onAppear(perform: openLimitIfRehearsing)
    }

    /// Nothing at all, except when a screenshot is being taken of the limit
    /// screen. See `Rehearsal`, which does not exist outside a debug build.
    private func openLimitIfRehearsing() {
        #if DEBUG
        if Rehearsal.opensLimit { isChangingLimit = true }
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

                // The pill carries a search too, announced by the same name —
                // which is right for a reader and ambiguous for a test. An
                // identifier is not spoken aloud and tells the two apart.
                Step("Find someone", identifier: "panel.findSomeone", action: onFindSomeone)

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
        String(localized: "Resets at \(Phrase.clockTime(session.resetsAt)). Only time with Instagram on screen counts.")
    }

    // MARK: - How long the wait is

    /// The one number in the app that had to be allowed to move, and the one
    /// that most obviously must not move freely.
    ///
    /// A week is the rule the app was built around and it is also somebody's
    /// guess. For a reader who knows themselves it is the wrong guess in a
    /// knowable direction, and refusing to let them be stricter would be the
    /// app standing between somebody and a smaller number — the exact thing it
    /// promises never to do.
    ///
    /// So it moves, under the same asymmetry as everything else: longer at
    /// once, shorter only after the wait it is trying to shorten. Read the
    /// other way round, that is the whole point — without it, the cooldown
    /// would be the single dial you could turn down at the moment it started
    /// to bite, and the app would have spent all this effort building a door
    /// into its own rule.
    private var theWait: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            HStack(spacing: 10) {
                ForEach(LimitPolicy.cooldowns, id: \.self) { days in
                    wait(days)
                }
            }

            if let waitRefused {
                Note(verbatim: waitRefused)
            } else {
                Note("Asking to wait longer takes effect at once. Asking to wait less has to wait — otherwise this would be the one rule you could relax at the moment it started to matter.")
            }
        }
    }

    private func wait(_ days: Int) -> some View {
        let chosen = session.limit.cooldownDays == days
        return Button {
            waitRefused = nil
            if case let .failure(refusal) = session.requestCooldown(days) {
                waitRefused = explain(refusal)
            }
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

    /// The same words the change screen uses, because they are answers to the
    /// same refusals and two wordings would be two rules.
    private func explain(_ refusal: LimitRefusal) -> String? {
        switch refusal {
        case .unchanged:
            return nil
        case let .tooSoon(next):
            return String(localized: "You can shorten the wait once the wait is over, \(Phrase.day(next, relativeTo: session.today)).")
        case .clockRewound:
            return String(localized: "The date on this phone is behind where Quiet last saw it. The wait can be made longer, but not shorter, until it catches up.")
        case .clockAdvanced:
            return String(localized: "The date on this phone is ahead of Instagram's. The wait can be made longer, but not shorter, until the two agree.")
        case .outOfRange:
            return nil
        }
    }

    // MARK: - What the app says on the way down

    /// The one setting that changes what the app says rather than what it
    /// allows.
    ///
    /// It is not a hole in the rule and it was worth checking that twice. A
    /// warning changes nothing about how much time there is: the limit is the
    /// limit whether or not anybody is counted down to it, the curtain falls
    /// at the same second either way, and turning this off buys not one
    /// minute. The single argument this app refuses to have is about *how
    /// much*, and this is not that argument.
    ///
    /// What it does buy, for some people, is not being told. "Five minutes
    /// left" is a useful thing to hear and it is also, for a certain kind of
    /// reader, the sentence that starts a last five minutes. Both are true and
    /// neither is true of everybody, which is exactly the shape of a setting.
    private var warnings: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            Toggle(isOn: Binding(
                get: { preferences.saysWhatIsLeft },
                set: { preferences.saysWhatIsLeft = $0 }
            )) {
                Text("Say what is left")
                    .font(.quietBody)
            }
            .tint(Paper.ink)

            Note("Two quiet notices, at five minutes and at one. Turning them off does not add any time — the day ends at the same moment either way.")
        }
    }

    // MARK: - What is in the feed

    /// The one setting that changes what Instagram is allowed to show you.
    ///
    /// After the people you follow, Instagram's feed goes on with suggested
    /// posts from people you did not choose. The app used to take every one of
    /// them out, always, and that was not a choice anybody had made — it was
    /// this app deciding what somebody's feed should contain, which is the
    /// thing it objects to when the site does it.
    ///
    /// So they are shown, and there is a switch. Off, the feed is exactly what
    /// Instagram sends; on, it stops at the last post by somebody you chose,
    /// and Quiet says so where it stops.
    ///
    /// It is not the Reels rule and cannot be made into one. A block of Reels
    /// in the feed goes either way — that is refused by address in three other
    /// places and a setting about suggestions does not get to undo it.
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            Toggle(isOn: Binding(
                get: { !preferences.showsSuggestions },
                set: { preferences.showsSuggestions = !$0 }
            )) {
                Text("Hide suggested posts")
                    .font(.quietBody)
            }
            .tint(Paper.ink)

            Note("Instagram fills the feed with posts from people you do not follow once it runs out of the ones you do. Off, you see them all. On, the feed stops where the people you chose stop.")
        }
    }

    // MARK: - A time for Instagram

    /// The one thing Quiet does that a notification usually does, and the one
    /// it cannot.
    ///
    /// It cannot tell you that a message arrived. Nothing outside Instagram's
    /// own app can — that would take something, somewhere else, logged in as
    /// you, and this app is built around never being that. What it can do is
    /// take the *reason* to keep checking away: the window has an hour, and
    /// the hour finds you rather than the other way round.
    ///
    /// And it is silent on a day you have already been. A reminder that the
    /// window is open is useful; the same reminder after you have been through
    /// it is an invitation to a second visit, which is the opposite of the
    /// point.
    private var appointment: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            Toggle(isOn: Binding(
                get: { session.appointment.isOn },
                set: { wanted in
                    appointmentRefused = false
                    guard wanted else {
                        session.turnOffAppointment()
                        return
                    }
                    Task {
                        let granted = await session.turnOnAppointment()
                        appointmentRefused = !granted
                    }
                }
            )) {
                Text("A time for Instagram")
                    .font(.quietBody)
            }
            .tint(Paper.ink)

            if session.appointment.isOn {
                DatePicker(
                    "",
                    selection: appointmentHour,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityLabel(Text("The hour Quiet reminds you"))
            }

            if appointmentRefused {
                Note("This phone has notifications turned off for Quiet, so the reminder has nowhere to arrive. It can be switched on again in Settings.")
            } else {
                Note("One reminder a day, at an hour you choose — and none at all on a day you have already been. It cannot say whether anything happened on Instagram; nothing outside Instagram's own app can. What it can do is give the checking an hour, so the rest of the day does not need one.")
            }
        }
    }

    /// The hour as a `Date`, because that is what a time picker speaks. Only
    /// the hour and the minute survive the round trip; the day it happens to be
    /// attached to is thrown away on the way back in.
    private var appointmentHour: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                return calendar.date(
                    bySettingHour: session.appointment.hour,
                    minute: session.appointment.minute,
                    second: 0,
                    of: calendar.startOfDay(for: Date()),
                    matchingPolicy: .nextTime
                ) ?? Date()
            },
            set: { chosen in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: chosen)
                session.moveAppointment(to: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            }
        )
    }

    // MARK: - Your other devices

    /// The only thing in Quiet that sends anything anywhere.
    ///
    /// Two phones with a thirty-minute limit are an hour, and that is not a
    /// detail — it is the whole rule, walked around by owning an iPad. So the
    /// limit, the wait and today's total can follow you, through your own
    /// iCloud, where nobody else can read them.
    ///
    /// Off until asked for, because a thing that leaves the phone should be a
    /// thing somebody switched on. And what happens when two devices disagree
    /// is not left to whichever spoke last: the rules are written down in one
    /// place, with the same asymmetry as everything else here. Less time never
    /// waits; more time does.
    private var otherDevices: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            Toggle(isOn: Binding(
                get: { session.carriesBetweenDevices },
                set: { session.carryBetweenDevices($0) }
            )) {
                Text("Carry this between your devices")
                    .font(.quietBody)
            }
            .tint(Paper.ink)

            Note("Your limit, your wait and today's total, kept in your own iCloud so a second device is not a second allowance. Nothing else is sent, and nobody but you can read it — not even us, because there is no us: Quiet has no server and no account. Switching this off takes the copy down again.")
        }
    }

    // MARK: - The row along the bottom

    /// The one thing in Quiet that is purely a matter of taste.
    ///
    /// Everything else in this panel changes what the app does. This changes
    /// what it looks like, and it exists because both answers were built and
    /// neither turned out to be wrong: the bar is what Instagram draws, the
    /// island is the nicer object. Two names and a tap, not a screen.
    private var rowShape: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            HStack(spacing: 10) {
                ForEach(RowShape.allCases, id: \.self) { shape in
                    choice(shape)
                }
            }

            Note("The bar is the shape Instagram uses. The island floats over the page, and draws itself in while the page is moving.")
        }
    }

    private func choice(_ shape: RowShape) -> some View {
        let chosen = preferences.row == shape
        return Button {
            preferences.row = shape
        } label: {
            Text(shape.name)
                .font(.quietBody)
                .foregroundStyle(chosen ? Paper.page : Paper.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(chosen ? Paper.ink : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(Paper.rule, lineWidth: chosen ? 0 : 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    // MARK: - Instagram on this phone

    /// The two doors that are only housekeeping: the sign-in this app is
    /// holding, and the pile of pages it has kept so the site is quick.
    ///
    /// They are together and away from the limit because neither of them
    /// touches it, and that is the thing somebody signing out at midnight most
    /// needs to be sure of. The dialog says so; standing them under their own
    /// head says it before the dialog has to.
    private var instagramHere: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()

            Door("Sign out of Instagram") {
                isConfirmingSignOut = true
            }
            .confirmationDialog(
                "Sign out of Instagram?",
                isPresented: $isConfirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    surface.signOut()
                    onDismiss()
                }
            } message: {
                Text("This clears the Instagram session from this app. Your daily limit stays as it is.")
            }

            Hairline()

            Door("Clear cached pages", isEnabled: !hasCleared) {
                surface.clearCaches()
                hasCleared = true
            }

            Hairline()

            Group {
                if hasCleared {
                    Note("Cleared.")
                } else {
                    Note("Months of pages, pictures and answers are kept so the site is quick. Throwing them away costs a slower page or two and does not sign you out.")
                }
            }
            .padding(.top, Metric.underControl)
        }
    }

    // MARK: - The way out

    /// The door that was missing.
    ///
    /// The limit lives in the keychain because it has to outlive the app being
    /// deleted; that is the promise and the setup screen says so. What nobody
    /// wrote down is the consequence: there was no way out at all. The only
    /// exit was for somebody to know that a keychain exists and to go and find
    /// it, which is not an exit — it is a trap with documentation.
    ///
    /// So the door exists, and it is the same shape as every other door here.
    /// It opens slowly, after the wait currently in force, and it can be shut
    /// again at any moment before then for nothing. Somebody changing their
    /// mind about being released is asking to be held to the rule, and the app
    /// has never stood in the way of that.
    ///
    /// It has a head of its own now rather than a line in the middle of the
    /// small print. It is the most consequential thing on this screen and it
    /// was set in the same ink as the paragraph about analytics.
    @ViewBuilder
    private var letGo: some View {
        if let day = session.forgetOn {
            VStack(alignment: .leading, spacing: 0) {
                Text("Quiet forgets everything \(Phrase.day(day, relativeTo: session.today)).")
                    .font(.quietBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Metric.underControl)

                Hairline()
                Door("Keep my limit") { session.keepRemembering() }
                Hairline()

                Note("Until that day nothing changes. Changing your mind costs nothing and can be done at any time.")
                    .padding(.top, Metric.underControl)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Hairline()

                Door("Make Quiet forget everything") {
                    isConfirmingForget = true
                }
                .confirmationDialog(
                    "Make Quiet forget everything?",
                    isPresented: $isConfirmingForget,
                    titleVisibility: .visible
                ) {
                    Button("Ask to be forgotten", role: .destructive) {
                        session.askToBeForgotten()
                    }
                } message: {
                    Text("Your limit, your day and the wait are thrown away — after \(Phrase.days(session.limit.cooldownDays)), not now. You can call it off at any time before then. Your Instagram sign-in is a separate thing and is not touched.")
                }

                Hairline()
            }
        }
    }

    // MARK: - About

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            Note("Quiet has no account, no server of its own and no analytics. It stores six things on this phone: your limit, today's total, the last time it saw, the day you set it up, whether you have asked it to forget, and what your other devices have spent today.")
            Note("If you carry it between your devices, three of those go into your own iCloud — the limit, the wait, and how much each device has spent today. Nothing else, nowhere else, and only while the switch above is on.")
            Note("Your limit is kept in the keychain, which outlives the app. Deleting Quiet and installing it again does not reset it.")
            Note("Quiet is not affiliated with or endorsed by Instagram or Meta.")

            signature
        }
    }

    /// The app signing its name, the way it does at the foot of the opening and
    /// on the blank before the first page. Small, centred, nobody has to look
    /// at it — and it gives the version number something to be under instead of
    /// leaving the page to stop mid-paragraph.
    private var signature: some View {
        VStack(spacing: 8) {
            Hourglass(height: 18)
            Text(verbatim: Build.versionLine)
                .font(.quietFine)
                .foregroundStyle(Paper.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    // MARK: - When something has gone wrong quietly

    /// Nothing at all, on almost every launch.
    ///
    /// Three failures in this app are silent by nature, and silence is exactly
    /// what makes them expensive. None of them stops the app; all of them stop
    /// it doing something it says it does, and without a line here the first
    /// person to find out is somebody scrolling a real feed and wondering.
    ///
    /// The two failures that are *not* quiet — the trim files missing from the
    /// bundle, and a keychain refusing writes — are not repeated here. Both
    /// already carry a red band across the top of the browsing screen, which is
    /// where somebody is when they happen, and saying a thing twice in two
    /// registers makes the loud one quieter rather than the quiet one louder.
    ///
    /// Written as facts rather than as alarms. Every one of these leaves the
    /// address rules standing — Reels and Explore are refused because of where
    /// they are, and no amount of Instagram redesigning changes that — so the
    /// sentence says what stopped rather than implying the app has fallen over.
    ///
    /// It sat at the top of the About block until the screenshot showed what
    /// that looked like: a report that one of Quiet's two locks had not loaded,
    /// set in exactly the same fine soft type as the paragraph about analytics,
    /// under a head reading "About Quiet". It read as boilerplate, which is the
    /// one thing it is not. So it has a head of its own — and the head is only
    /// there on the launches where the report is, which is almost none of them.
    private var trouble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if surface.health.hasLostTheShape {
                Note("Quiet has not been able to find Instagram's own layout on the last few pages. Instagram has probably changed something. Reels and Explore are still closed — those are refused by address — but the tidying up around them may not be.")
            }
            if surface.blockListFailed {
                Note("Quiet's second lock did not load this time. Reels and Explore are still refused; there is one layer doing it rather than two.")
            }
            if let host = surface.handedOff {
                Note("A page at \(host) was opened in Safari during a sign-in. If signing in did not work, that is the address to report.")
            }
        }
    }

    private var hasTrouble: Bool {
        surface.health.hasLostTheShape || surface.blockListFailed || surface.handedOff != nil
    }

    // MARK: - The furniture

    /// The distances the page is built out of, in one place, because a rhythm
    /// is a thing you can only keep if the numbers keeping it have names.
    private enum Metric {
        /// Over a running head. Doing the work nine identical rules used to do,
        /// and doing it better.
        static let betweenGroups: CGFloat = 34
        /// Under a running head, before the first thing it names.
        static let underHeading: CGFloat = 14
        /// Between a control and the sentence explaining it.
        static let underControl: CGFloat = 10
        /// Over and under the words in a row you can press. Two of these plus a
        /// line of body text is a comfortable target on glass.
        static let rowPadding: CGFloat = 14
    }

    /// A running head: small, tracked capitals in soft ink.
    ///
    /// The capitals are the whole point. This page is nine tenths prose, and
    /// every other way of marking a heading — bigger, bolder, a different face —
    /// still leaves something the eye reads as a sentence and has to finish
    /// before it knows it was a label. Small capitals are read as a label
    /// before they are read at all, which is what a running head is for. They
    /// grow with the reader's text size like everything else, and VoiceOver
    /// gets the string as it was written, not as it is drawn.
    private struct Cluster<Content: View>: View {
        private let heading: LocalizedStringKey
        private let content: Content

        init(_ heading: LocalizedStringKey, @ViewBuilder content: () -> Content) {
            self.heading = heading
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Metric.underHeading) {
                Text(heading)
                    .font(.quietSmall.weight(.medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Metric.betweenGroups)
        }
    }

    /// A rule between two rows of the same table, and nowhere else.
    private struct Hairline: View {
        var body: some View {
            Divider().overlay(Paper.rule)
        }
    }

    /// A row that takes you somewhere: it has a chevron, and the chevron means
    /// what it means everywhere else on a phone.
    ///
    /// The name and the value share a line, and stop sharing one when they
    /// cannot. At the largest text sizes "Daily limit" and "20 minutes" both
    /// wrap, and a row of two two-line columns fighting over the same width is
    /// not a row any more — the accessibility screenshot is where that shows
    /// up, and it showed up. Past the ordinary sizes the value goes underneath
    /// the name, where each of them gets the whole width.
    private struct Step: View {
        private let title: LocalizedStringKey
        private let value: String?
        private let identifier: String
        private let action: () -> Void

        @Environment(\.dynamicTypeSize) private var typeSize

        init(
            _ title: LocalizedStringKey,
            value: String? = nil,
            identifier: String = "",
            action: @escaping () -> Void
        ) {
            self.title = title
            self.value = value
            self.identifier = identifier
            self.action = action
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                            if let value {
                                Text(value)
                                    .foregroundStyle(Paper.inkSoft)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                    } else {
                        Text(title)
                        Spacer(minLength: 8)
                        if let value {
                            Text(value)
                                .foregroundStyle(Paper.inkSoft)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.quietSmall.weight(.semibold))
                        .foregroundStyle(Paper.inkSoft)
                }
                .font(.quietBody)
                .padding(.vertical, Metric.rowPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
        }
    }

    /// A row where something happens rather than one that goes somewhere, so no
    /// chevron — and no red either. The two that deserve a warning ask for
    /// confirmation, and a warning belongs in the question, not on the handle.
    private struct Door: View {
        private let title: LocalizedStringKey
        private let isEnabled: Bool
        private let action: () -> Void

        init(_ title: LocalizedStringKey, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.title = title
            self.isEnabled = isEnabled
            self.action = action
        }

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.quietBody)
                    .foregroundStyle(isEnabled ? Paper.ink : Paper.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Metric.rowPadding)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
    }

    private struct Note: View {
        let text: Text

        /// A literal, so that it is translated. `Text(someString)` is verbatim
        /// by design, which is right for a version number and wrong for a
        /// sentence — hence the two ways in.
        init(_ key: LocalizedStringKey) { text = Text(key) }
        init(verbatim: String) { text = Text(verbatim: verbatim) }

        var body: some View {
            text
                .font(.quietFine)
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum Build {
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "Version \(version) (\(build))")
    }
}
