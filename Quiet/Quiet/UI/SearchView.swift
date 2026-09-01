import SwiftUI
import UIKit

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
    /// Leaving without opening anybody. Handed in rather than taken from the
    /// environment, because this is a page inside the browsing screen as often
    /// as it is a sheet over the curtain, and a page has no `dismiss` to call.
    var onDone: () -> Void
    var onOpen: (URL) -> Void

    @State private var query = ""
    @State private var found: [Person] = []
    /// The handful of people this phone actually opens.
    @State private var recent: [String] = Remembered.visits()
    @State private var outcome = Outcome.idle
    @State private var asking: Task<Void, Never>?
    @FocusState private var isFocused: Bool
#if DEBUG
    @State private var whereIAm: CGFloat = -1
#endif

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
                    if outcome == .idle, !recent.isEmpty {
                        recents
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
                    Button("Done", action: onDone)
                }
            }
            .toolbarBackground(Paper.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        // Deliberately not `.ignoresSafeArea(.keyboard)`. That reads like the
        // way to say "do not move for a keyboard" and it is the opposite: it
        // *expands* the view to cover the region it ignores, so this page
        // asked its container for its own height plus the keyboard's — and the
        // stack it stands in answered by overflowing, which is where the
        // seventy-six points came from. The page not moving is settled where
        // it belongs, by the stack having a size. See `quietPages`.
        .presentationBackground(Paper.page)
#if DEBUG
        // Where this page actually is on the glass, which is the question the
        // photograph could not answer: a page whose top strip has collapsed and
        // a page that has been slid upward look identical, and only one of them
        // is about the safe area.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { whereIAm = proxy.frame(in: .global).minY }
                    .onChange(of: proxy.frame(in: .global).minY) { whereIAm = $1 }
            }
        )
#endif
        .onAppear(perform: rehearse)
        .onDisappear { asking?.cancel() }
    }

    /// A staged photograph with the keyboard up, and what the app read while
    /// it was.
    ///
    /// Nothing here runs in a build anybody can install — `Rehearsal` is `#if
    /// DEBUG` in its entirety. It exists because the defect it was written for
    /// cannot be seen without a keyboard: a keyboard puts a second full-screen
    /// window in front of the app's, and the app used to take the height of the
    /// notch from whichever window had the keys.
    private func rehearse() {
#if DEBUG
        guard Rehearsal.opensKeyboard else { return }
        isFocused = true
        Task {
            // After the keyboard, not before it. The window that breaks the
            // reading does not exist until it is on screen.
            try? await Task.sleep(for: .seconds(2))
            NSLog("Quiet: %@, page at %.1f", SafeArea.reading, Double(whereIAm))
        }
#endif
    }

    private var field: some View {
        HStack(spacing: 10) {
            Text("@")
                .foregroundStyle(Paper.inkSoft)
            TextField("name", text: $query)
                // The web view behind this page has fields of its own — a login
                // form, a comment box — and a test looking for "the first text
                // field" can find one of those instead. A name it cannot
                // confuse is not spoken aloud and costs nothing.
                .accessibilityIdentifier("search.field")
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
                        HStack(spacing: 13) {
                            face(of: person)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.username)
                                    .font(.quietBody)
                                if !person.name.isEmpty {
                                    Text(person.name)
                                        .font(.quietSmall)
                                        .foregroundStyle(Paper.inkSoft)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens this profile"))

                    Divider()
                        .overlay(Paper.rule)
                        .padding(.leading, 85)
                }
            }
            .padding(.top, 14)
        }
        // Three names do not fill the glass, and a list of three that bounces
        // is a list claiming to have more.
        .scrollBounceBehavior(.basedOnSize)
    }

    /// The three or four people you came here for.
    ///
    /// Instagram's search tab is the front door to Explore, which is why it is
    /// gone; what a person actually wanted from it was *who is my friend on
    /// here*, and for most people that is the same short list every time. This
    /// is that list, and it is deliberately not a history: no dates, no order
    /// of interest, no count, nothing to feel anything about. Eight names, most
    /// recent first, and a way to wipe them.
    ///
    /// It answers before a single letter is typed, which is the entire point —
    /// a search that has to be searched is a search.
    private var recents: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recently opened")
                    .font(.quietSmall)
                    .foregroundStyle(Paper.inkSoft)
                Spacer()
                Button("Clear") {
                    Remembered.forgetVisits()
                    recent = []
                }
                .font(.quietSmall)
                .foregroundStyle(Paper.inkSoft)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 4)

            ForEach(recent, id: \.self) { handle in
                Button {
                    open(handle)
                } label: {
                    HStack(spacing: 13) {
                        Circle()
                            .fill(Paper.ink.opacity(0.08))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(handle.prefix(1)).uppercased())
                                    .font(.quietSmall)
                                    .foregroundStyle(Paper.inkSoft)
                            )
                        Text(handle)
                            .font(.quietBody)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens this profile"))
            }
        }
    }

    /// The face, or the letter that stands in for one.
    ///
    /// A picture that will not load is not worth an error or an empty ring: the
    /// first letter of the name, set on paper, is a perfectly good way to tell
    /// six rows apart.
    @ViewBuilder
    private func face(of person: Person) -> some View {
        if let image = person.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Paper.ink.opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(person.username.prefix(1)).uppercased())
                        .font(.quietBody)
                        .foregroundStyle(Paper.inkSoft)
                )
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
        // The name as the app will use it, rather than as it was typed: a
        // pasted link and an @ in front of it are the same person.
        if let name = ContentRules.pathComponents(of: url).first {
            Remembered.remember(visit: name)
            recent = Remembered.visits()
        }
        onOpen(url)
    }
}
