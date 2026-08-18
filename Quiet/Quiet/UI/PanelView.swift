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
                LimitView(session: session) { onDismiss() }
            }
            .toolbarBackground(Paper.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(Paper.page)
    }

    // MARK: - Today

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headline)
                .font(.quietTitle(30))

            Text(subhead)
                .font(.system(size: 14))
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Paper.inkSoft)
                }
                .font(.system(size: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 24)

            if let pending = session.limit.pending {
                Text("\(Phrase.minutes(pending.minutes)) from \(Phrase.day(pending.effective, relativeTo: session.today)).")
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 6)
            }

            if session.isClockRewound {
                Text("The date on this phone is behind where Quiet last saw it. The limit can be lowered, but not raised, until it catches up.")
                    .font(.system(size: 13))
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
                .font(.system(size: 16))

            HStack(spacing: 10) {
                Text("@")
                    .foregroundStyle(Paper.inkSoft)
                TextField("username", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(open)
                Button("Go", action: open)
                    .font(.system(size: 15, weight: .medium))
                    .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.system(size: 16))
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Paper.ink.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Quiet has no search page, because search is where Explore lives. Typing a name goes straight to that profile.")
                .font(.system(size: 13))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func open() {
        guard let url = ContentRules.profile(forHandle: handle) else {
            session.show("That doesn't look like a username.")
            return
        }
        surface.open(url)
        handle = ""
        onDismiss()
    }

    // MARK: - About

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("Sign out of Instagram") {
                isConfirmingSignOut = true
            }
            .font(.system(size: 16))
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
                Note("Quiet has no account, no servers and no analytics. It stores four things on this phone: your limit, today's total, the last time it saw, and whether setup is done.")
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
                .font(.system(size: 12))
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
