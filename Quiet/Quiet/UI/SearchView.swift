import SwiftUI

/// Finding a person.
///
/// Instagram's search tab is the front door to Explore, which is why it is gone.
/// What a person actually wanted from it — *who is my friend on here* — is this
/// screen, and nothing else: names, at most six, and no way to fall out of it
/// into a grid of strangers.
///
/// The searching is done by Instagram's own page, with the page's own cookies,
/// so the answers are the site's real answers and Quiet still makes no request
/// of its own.
@MainActor
struct SearchView: View {
    let surface: WebSurface
    var onOpen: (URL) -> Void

    @State private var query = ""
    @State private var found: [Person] = []
    @State private var outcome = Outcome.idle
    @State private var asking: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private enum Outcome: Equatable {
        case idle, asking, answered, unavailable
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                field

                if found.isEmpty {
                    if let sentence = explanation {
                        Text(sentence)
                            .font(.quietSmall)
                            .foregroundStyle(Paper.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                    }
                    Spacer()
                } else {
                    results
                }
            }
            .quietPage()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Find someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(Paper.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(Paper.page)
        .onAppear { isFocused = true }
        .onDisappear { asking?.cancel() }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Text("@")
                .foregroundStyle(Paper.inkSoft)
            TextField("name", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit(exactly)
                .onChange(of: query) { look() }
            if !query.isEmpty {
                Button {
                    query = ""
                    look()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Paper.inkSoft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .font(.quietBody)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Paper.ink.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(found) { person in
                    Button {
                        open(person.username)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.username)
                                .font(.quietBody)
                            if !person.name.isEmpty {
                                Text(person.name)
                                    .font(.quietSmall)
                                    .foregroundStyle(Paper.inkSoft)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens this profile"))

                    Divider()
                        .overlay(Paper.rule)
                        .padding(.horizontal, 28)
                }
            }
            .padding(.top, 14)
        }
    }

    /// One sentence, or none when the answer is the list itself.
    private var explanation: String? {
        switch outcome {
        case .idle:
            return String(localized: "Type a name. Quiet searches for people and nothing else — no Explore, no hashtags, no places.")
        case .asking:
            return String(localized: "Looking…")
        case .answered:
            return String(localized: "Nobody by that name.")
        case .unavailable:
            return String(localized: "Search is not answering. An exact name still works: type it and press search.")
        }
    }

    /// Ask a moment after the typing stops, not on every letter. There is a real
    /// question going to Instagram here, and no reason to ask it six times for
    /// one name.
    private func look() {
        asking?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            found = []
            outcome = .idle
            return
        }
        outcome = .asking
        asking = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let people = await surface.people(matching: term)
            guard !Task.isCancelled else { return }
            found = people ?? []
            outcome = people == nil ? .unavailable : .answered
        }
    }

    /// The return key: go to exactly what was typed, which is what somebody who
    /// already knows the name expects.
    private func exactly() {
        open(query)
    }

    private func open(_ handle: String) {
        guard let url = ContentRules.profile(forHandle: handle) else { return }
        asking?.cancel()
        onOpen(url)
        dismiss()
    }
}
