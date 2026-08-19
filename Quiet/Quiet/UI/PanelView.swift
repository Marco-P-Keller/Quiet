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
        case .spent: return "No time left today."
        default: return "\(Phrase.remaining(session.remaining)) left today."
        }
    }

    private var subhead: String {
        "Resets at \(Phrase.clockTime(session.resetsAt)). Only time with Instagram on screen counts."
    }

    // MARK: - Find someone

    private var findSomeone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find someone")
                .font(.quietBody)

            HStack(spacing: 10) {
                Text("@")
                    .foregroundStyle(Paper.inkSoft)
                TextField("username", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(open)
                    .onChange(of: handle) { handleProblem = nil }
                Button("Go", action: open)
                    .font(.quietAction)
                    .disabled(trimmedHandle.isEmpty)
            }
            .font(.quietBody)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Paper.ink.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Said here rather than as a floating notice: the panel is covering
            // the screen a notice would appear on, and an answer nobody can see
            // is the same as no answer.
            Text(handleProblem ?? "Quiet has no search page, because search is where Explore lives. Typing a name goes straight to that profile.")
                .font(.quietSmall)
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trimmedHandle: String {
        handle.trimmingCharacters(in: .whitespaces)
    }

    private func open() {
        guard let url = ContentRules.profile(forHandle: handle) else {
            handleProblem = "That doesn't look like a username."
            return
        }
        surface.open(url)
        handle = ""
        handleProblem = nil
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
                Note(Build.versionLine)
            }
            .padding(.top, 6)
        }
    }

    private struct Note: View {
        let text: String

        init(_ text: String) { self.text = text }

        var body: some View {
            Text(text)
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
        return "Version \(version) (\(build))"
    }
}
