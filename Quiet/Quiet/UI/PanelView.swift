import SwiftUI

/// Everything Quiet can be told to do, on one screen.
///
/// It is short on purpose. An app with a settings screen you can get lost in has
/// already lost the argument it was built to win.
@MainActor
struct PanelView: View {
    let session: QuietSession
    let surface: WebSurface
    var onDismiss: () -> Void

    @State private var handle = ""
    @State private var handleProblem: String?
    @State private var found: [Person] = []
    @State private var search = Search.idle
    @State private var searching: Task<Void, Never>?
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

    /// What the search is doing, which the panel has to be able to say.
    private enum Search: Equatable {
        /// Nothing typed yet.
        case idle
        /// Typed, and the page has been asked.
        case asking
        /// Asked and answered — `found` holds the answer, empty or not.
        case answered
        /// Could not ask at all: offline, signed out, or the endpoint moved.
        /// A different thing from nobody being called that.
        case unavailable
    }

    private var findSomeone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find someone")
                .font(.quietBody)

            HStack(spacing: 10) {
                Text("@")
                    .foregroundStyle(Paper.inkSoft)
                TextField("name", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(open)
                    .onChange(of: handle) { handleProblem = nil; look() }
                Button("Go", action: open)
                    .font(.quietAction)
                    .disabled(trimmedHandle.isEmpty)
            }
            .font(.quietBody)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Paper.ink.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !found.isEmpty {
                results
            }

            // Said here rather than as a floating notice: the panel is covering
            // the screen a notice would appear on, and an answer nobody can see
            // is the same as no answer.
            if let sentence = explanation {
                Text(sentence)
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear { searching?.cancel() }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(found.enumerated()), id: \.element.id) { index, person in
                if index > 0 {
                    Divider().overlay(Paper.rule)
                }
                Button {
                    go(to: person.username)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.username)
                            .font(.quietBody)
                        if !person.name.isEmpty {
                            Text(person.name)
                                .font(.quietSmall)
                                .foregroundStyle(Paper.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens this profile"))
            }
        }
    }

    /// One sentence under the field, or none when the answer is the list itself.
    private var explanation: String? {
        if let handleProblem { return handleProblem }
        switch search {
        case .idle:
            return String(localized: "Type a name. Quiet searches for people and nothing else — no Explore, no hashtags, no places.")
        case .asking:
            return found.isEmpty ? String(localized: "Looking…") : nil
        case .answered:
            return found.isEmpty ? String(localized: "Nobody by that name.") : nil
        case .unavailable:
            return String(localized: "Search is not answering. An exact name still works: type it and tap Go.")
        }
    }

    /// Ask a moment after the typing stops, not on every letter. Instagram is
    /// being asked a real question here and there is no reason to ask it six
    /// times for one name.
    private func look() {
        searching?.cancel()
        let query = trimmedHandle
        guard query.count >= 2 else {
            found = []
            search = .idle
            return
        }
        search = .asking
        searching = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let people = await surface.people(matching: query)
            guard !Task.isCancelled else { return }
            found = people ?? []
            search = people == nil ? .unavailable : .answered
        }
    }

    private func go(to username: String) {
        guard let url = ContentRules.profile(forHandle: username) else { return }
        surface.open(url)
        reset()
        onDismiss()
    }

    private func reset() {
        searching?.cancel()
        handle = ""
        handleProblem = nil
        found = []
        search = .idle
    }

    private var trimmedHandle: String {
        handle.trimmingCharacters(in: .whitespaces)
    }

    private func open() {
        guard let url = ContentRules.profile(forHandle: handle) else {
            handleProblem = String(localized: "That doesn't look like a username.")
            return
        }
        surface.open(url)
        reset()
        onDismiss()
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

            VStack(alignment: .leading, spacing: 8) {
                Note("Quiet has no account, no servers and no analytics. It stores four things on this phone: your limit, today's total, the last time it saw, and the day you set it up.")
                Note("Your limit is kept in the keychain, which outlives the app. Deleting Quiet and installing it again does not reset it.")
                Note("Quiet is not affiliated with or endorsed by Instagram or Meta.")
                Note(verbatim: Build.versionLine)
            }
            .padding(.top, 6)
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
