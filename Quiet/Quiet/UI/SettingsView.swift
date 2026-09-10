import SwiftUI

/// Everything Quiet can be told to do that is not the day you are having.
///
/// The panel in front of this holds two things: how much time is left, and what
/// the days behind you came to. Those are what somebody opens the panel *for*.
/// Everything here is a decision made once and then lived with — the wait, what
/// the feed contains, what the app says and when, the shape of the row, the way
/// out — and a list of eight of them standing between a reader and the two
/// numbers they came for made the numbers harder to find every single time, to
/// save a tap on the rare occasion any of this changes.
///
/// It is still short. An app with a settings screen you can get lost in has
/// already lost the argument it was built to win, and this is the same screen it
/// always was, one door further in.
@MainActor
struct SettingsView: View {
    let session: QuietSession
    let surface: WebSurface
    let preferences: Preferences

    /// Closing the panel entirely, from a screen pushed on top of it. Signing
    /// out of Instagram wants the whole thing gone, not this screen popped off
    /// to reveal a panel over a page that has just changed underneath it.
    var onDismiss: () -> Void

    @State private var isConfirmingSignOut = false
    @State private var isChangingBaseline = false

    /// Why the last request to change the wait was turned down, if it was.
    /// Cleared by the next tap, so it answers the thing that was just pressed
    /// rather than sitting there.
    @State private var waitRefused: String?
    /// Set when the phone declines notifications, so a switch can say why it
    /// slid back rather than just sliding back.
    @State private var appointmentRefused = false
    @State private var recapRefused = false
    @State private var isConfirmingForget = false
    @State private var hasCleared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Cluster("The days behind you") { theDayYouStartedFrom }

                Cluster("The wait between increases") { theWait }

                Cluster("What is in the feed") { suggestions }

                // Three switches under one head, because they answer the same
                // question — does the app speak to you, and when. A rule
                // between them, because they are three answers and not one. The
                // morning note sits last on purpose: the other two are about
                // the day you are in, and it is about the days you are not.
                Cluster("What Quiet says") {
                    warnings
                    Hairline().padding(.vertical, 4)
                    appointment
                    Hairline().padding(.vertical, 4)
                    morningNote
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
        .quietPage()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Paper.page, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - The days behind you

    /// The other end of the comparison the panel draws, and every sentence
    /// explaining what that comparison does and does not say.
    ///
    /// All of it used to sit under the chart, and all of it was true. It was
    /// also three paragraphs standing between a reader and a screen whose whole
    /// job is a number and a picture — read once, in front of you every time.
    /// Prose belongs on the screen you go to when you want prose.
    ///
    /// The number itself is free to move, in both directions, which is not a
    /// hole in anything: it touches no limit, no wait and no minute of today. It
    /// is one end of a comparison, and a comparison against a figure somebody
    /// knows to be wrong is worth nothing to them. The cost of leaving it open
    /// is that the figure in the panel is one you can flatter yourself with; the
    /// cost of sealing it would be that one mis-spun wheel on the first morning
    /// poisons it for good.
    private var theDayYouStartedFrom: some View {
        VStack(alignment: .leading, spacing: Metric.underControl) {
            Step(
                "The day you started from",
                value: session.baseline > 0
                    ? Phrase.minutes(session.baseline)
                    : String(localized: "not said"),
                identifier: "panel.theDayYouStartedFrom"
            ) {
                isChangingBaseline.toggle()
            }

            if isChangingBaseline {
                Picker("The day you started from", selection: Binding(
                    get: { session.baseline > 0 ? session.baseline : 60 },
                    set: { session.setBaseline($0) }
                )) {
                    ForEach(Self.baselines, id: \.self) { value in
                        Text(Phrase.minutes(value))
                            .font(.quietChoice)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                // See LimitView: a wheel's rows are a fixed height, so the
                // numbers collide past the largest ordinary text size.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            }

            Note("It changes nothing about your limit or your day. It is the number the chart is measured against, so it is worth it being the true one.")

            Note("Only time with Instagram on screen counts, and only on days Quiet was open — a day you did not open it counts for nothing either way. Quiet cannot see what any other app on this phone did with it.")

            if session.baseline > 0 {
                Note("On the chart, the dashed lines mark your limit and the day you started from. Either is left off when it sits so far above your days that drawing it would flatten them.")
            } else {
                Note("The dashed line on the chart is your limit. It is left off when it sits so far above your days that drawing it would flatten them.")
            }
        }
    }

    private static let baselines = [10, 15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480]

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

    // MARK: - The morning note

    /// The account, as against the invitation.
    ///
    /// A separate switch from the appointment above, and the separation is the
    /// point: one says the window is open and arrives *before*, the other says
    /// what the window came to and arrives *after*. Somebody working to open
    /// Instagram less may well want the second and want nothing at all to do
    /// with the first, and bundling them would mean the account could only be
    /// bought with the invitation.
    ///
    /// It says fewer minutes here, against a number the reader gave. It does
    /// not say time was won back, because Quiet has no idea where the time
    /// went and cannot see the real Instagram app at all — and a notification
    /// that overstates what an app did for you is worth less than no
    /// notification, twice over, because it is also the reason nobody believes
    /// the next one.
    private var morningNote: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { session.recap.isOn },
                set: { wanted in
                    recapRefused = false
                    guard wanted else {
                        session.turnOffRecap()
                        return
                    }
                    Task {
                        let granted = await session.turnOnRecap()
                        recapRefused = !granted
                    }
                }
            )) {
                Text("A note about the days behind you")
                    .font(.quietBody)
            }
            .tint(Paper.ink)
            .disabled(session.baseline == 0)

            // On *and* able to say something. Without the second half the hour
            // was offered under a switch that could not be moved, over a
            // sentence explaining that nothing would arrive — three controls
            // disagreeing about whether this feature is running.
            if session.recap.isOn, session.baseline > 0 {
                DatePicker(
                    "",
                    selection: recapHour,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityLabel(Text("The hour the note arrives"))
            }

            if recapRefused {
                Note("This phone has notifications turned off for Quiet, so the note has nowhere to arrive. It can be switched on again in Settings.")
            } else if session.baseline == 0 {
                Note("There is nothing to compare against yet. Say what your day used to be under The days behind you, and this can start.")
            } else {
                Note("One in the morning after a day you used Quiet, one after a week, one after a month. It says how long you were on Instagram and how much less that is than the \(Phrase.minutes(session.baseline)) a day you started from — nothing about the rest of your phone, which Quiet cannot see.")
            }
        }
    }

    private var recapHour: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                return calendar.date(
                    bySettingHour: session.recap.hour,
                    minute: session.recap.minute,
                    second: 0,
                    of: calendar.startOfDay(for: Date()),
                    matchingPolicy: .nextTime
                ) ?? Date()
            },
            set: { chosen in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: chosen)
                session.moveRecap(to: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
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

            Note("The bar is the shape Instagram uses. The island floats over the page and gets out of the way while you read.")

            // Only under the island. A bar stands on the bottom edge with the
            // page stopping above it, so it has nothing to float over and
            // nothing to get out of the way of — offering it a choice about how
            // it moves would be offering a choice that does nothing.
            if preferences.row == .island {
                Hairline().padding(.vertical, 4)

                Text("And how it gets out of the way")
                    .font(.quietBody)
                    .padding(.top, 4)

                HStack(spacing: 10) {
                    ForEach(RowMotion.allCases, id: \.self) { motion in
                        movement(motion)
                    }
                }

                Note("Sliding away is what Instagram's own bar does: scrolling down takes it off the screen and scrolling up brings it back. Drawing in keeps it there — smaller and fainter while the page moves, out again the moment it stops.")
            }
        }
    }

    private func movement(_ motion: RowMotion) -> some View {
        let chosen = preferences.rowMotion == motion
        return Button {
            preferences.rowMotion = motion
        } label: {
            Text(motion.name)
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
            Note("Quiet has no account, no server of its own and no analytics. It stores eight things on this phone: your limit, today's total, the last time it saw, the day you set it up, whether you have asked it to forget, what your other devices have spent today, the day you said you started from, and how long each day since has been.")
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
}
