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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    timeSection
                    Divider().overlay(Paper.rule).padding(.vertical, 24)
                    findSomeone
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

            VStack(alignment: .leading, spacing: 8) {
                Note("Quiet has no account, no servers and no analytics. It stores four things on this phone: your limit, today's total, the last time it saw, and the day you set it up.")
                Note("Your limit is kept in the keychain, which outlives the app. Deleting Quiet and installing it again does not reset it.")
                Note("Quiet is not affiliated with or endorsed by Instagram or Meta.")
                Note(verbatim: Build.versionLine)
            }
            .padding(.top, 6)
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
