import SwiftUI

/// Everything Quiet can be told to do, on one screen.
///
/// It is short on purpose. An app with a settings screen you can get lost in has
/// already lost the argument it was built to win.
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
    @State private var isConfirmingForget = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    timeSection
                    Divider().overlay(Paper.rule).padding(.vertical, 24)
                    theWait
                    Divider().overlay(Paper.rule).padding(.vertical, 24)
                    findSomeone
                    Divider().overlay(Paper.rule).padding(.vertical, 24)
                    warnings
                    Divider().overlay(Paper.rule).padding(.vertical, 24)
                    rowShape
                    Divider().overlay(Paper.rule).padding(.vertical, 24)
                    about
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

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headline)
                .font(.quietTitle)
                .fixedSize(horizontal: false, vertical: true)

            Text(subhead)
                .font(.quietNote)
                .foregroundStyle(Paper.inkSoft)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                isChangingLimit = true
            } label: {
                HStack {
                    Text("Daily limit")
                    Spacer()
                    Text(Phrase.minutes(session.limit.minutes))
                        .foregroundStyle(Paper.inkSoft)
                    Image(systemName: "chevron.right")
                        .font(.quietSmall.weight(.semibold))
                        .foregroundStyle(Paper.inkSoft)
                }
                .font(.quietBody)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 24)

            if let pending = session.limit.pending {
                Text("\(Phrase.minutes(pending.minutes)) from \(Phrase.day(pending.effective, relativeTo: session.today)).")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 6)
            }

            if session.isClockRewound {
                Text("The date on this phone is behind where Quiet last saw it. The limit can be lowered, but not raised, until it catches up.")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            } else if session.isClockAdvanced {
                // The other half of the same sentence. It reads as an accusation
                // if it is written as one, so it is not: two clocks disagree,
                // and the app says which one it is going by.
                Text("The date on this phone is ahead of Instagram's, so Quiet is going by Instagram's. The limit can be lowered, but not raised, until the two agree.")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 10)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("The wait between increases")
                .font(.quietBody)

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

    // MARK: - Find someone

    private var findSomeone: some View {
        Button {
            onFindSomeone()
        } label: {
            HStack {
                Text("Find someone")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.quietSmall.weight(.semibold))
                    .foregroundStyle(Paper.inkSoft)
            }
            .font(.quietBody)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The pill carries a search too, announced by the same name — which is
        // right for a reader and ambiguous for a test. An identifier is not
        // spoken aloud and tells the two apart.
        .accessibilityIdentifier("panel.findSomeone")
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
        VStack(alignment: .leading, spacing: 14) {
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

    // MARK: - The row along the bottom

    /// The one thing in Quiet that is purely a matter of taste.
    ///
    /// Everything else in this panel changes what the app does. This changes
    /// what it looks like, and it exists because both answers were built and
    /// neither turned out to be wrong: the bar is what Instagram draws, the
    /// island is the nicer object. Two names and a tap, not a screen.
    private var rowShape: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The row along the bottom")
                .font(.quietBody)

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

    // MARK: - About

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("Sign out of Instagram") {
                isConfirmingSignOut = true
            }
            .font(.quietBody)
            .buttonStyle(.plain)
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

            trouble

            letGo

            VStack(alignment: .leading, spacing: 8) {
                Note("Quiet has no account, no servers and no analytics. It stores five things on this phone: your limit, today's total, the last time it saw, the day you set it up, and whether you have asked it to forget.")
                Note("Your limit is kept in the keychain, which outlives the app. Deleting Quiet and installing it again does not reset it.")
                Note("Quiet is not affiliated with or endorsed by Instagram or Meta.")
                Note(verbatim: Build.versionLine)
            }
            .padding(.top, 6)
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
    @ViewBuilder
    private var letGo: some View {
        if let day = session.forgetOn {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quiet forgets everything \(Phrase.day(day, relativeTo: session.today)).")
                    .font(.quietBody)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Keep my limit") { session.keepRemembering() }
                    .font(.quietBody)
                    .buttonStyle(.plain)

                Note("Until that day nothing changes. Changing your mind costs nothing and can be done at any time.")
            }
        } else {
            Button("Make Quiet forget everything") {
                isConfirmingForget = true
            }
            .font(.quietBody)
            .buttonStyle(.plain)
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
        }
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
    @ViewBuilder
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
        .padding(.top, 6)
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
