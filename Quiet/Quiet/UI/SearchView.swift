import SwiftUI
import UIKit

/// Finding a person.
///
/// Instagram's search tab is the front door to Explore, which is why it is gone.
/// What a person actually wanted from it — *who is my friend on here* — is this
/// screen, and nothing else: names, and no way to fall out of them into a grid
/// of strangers.
///
/// ## It asks Instagram nothing, and that is the change
///
/// It used to, by calling `/api/v1/web/search/topsearch/` with Instagram's own
/// web client identifier in a header — the only way that endpoint answers
/// anybody. It gave results as you typed, and it made this app an unofficial
/// client of a private API, which is the one thing in the whole project Meta's
/// terms name outright. See `docs/store-and-legal.md`.
///
/// What stands there now is the list of people this phone actually opens,
/// narrowed as you type, with the typed name itself at the foot of it. Which is
/// the same screen for the case it was built for: for almost everybody the
/// answer to *who is my friend on here* is the same three or four people, and
/// for those it now answers with no request, no waiting and no spinner at all.
/// A stranger who has never been opened is the one case that lost something —
/// their name has to be typed exactly, and the last row opens it.
@MainActor
struct SearchView: View {
    /// No `WebSurface`. This screen held one for as long as it did the asking —
    /// six results and eight faces, both out of Instagram's private web API.
    /// It asks nothing now, so it holds nothing: what it knows it reads from
    /// `Remembered`, and the only thing it does to the app is hand an address
    /// back through `onOpen`.
    ///
    /// Leaving without opening anybody. Handed in rather than taken from the
    /// environment, because this is a page inside the browsing screen as often
    /// as it is a sheet over the curtain, and a page has no `dismiss` to call.
    var onDone: () -> Void
    var onOpen: (URL) -> Void

    @State private var query = ""
    /// The handful of people this phone actually opens.
    @State private var recent: [String] = Remembered.visits()
    /// Their faces, as they were known last time. Read before the first frame
    /// rather than fetched after it, so the list does not fill itself in while
    /// somebody is looking at it.
    @State private var faces: [String: UIImage] = Remembered.visitFaces()
    @FocusState private var isFocused: Bool
#if DEBUG
    @State private var whereIAm: CGFloat = -1
    @State private var whereTheFieldIs: CGFloat = -1
#endif

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                field

                if query.isEmpty {
                    Text(explanation)
                        .font(.quietSmall)
                        .foregroundStyle(Paper.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                    if !recent.isEmpty { recents }
                    Spacer()
                } else {
                    narrowedRows
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
        .onAppear(perform: refresh)
        .onAppear(perform: rehearse)
    }

    /// What the page learned while it was away.
    ///
    /// A face is written down at the moment a profile is opened, by the page
    /// that already had it — so the picture for somebody opened a minute ago
    /// arrives while this screen is not on the glass. Read again on the way in
    /// rather than watched for: this is a sheet that is made and thrown away,
    /// and the one moment it can be wrong is the one it is built in.
    private func refresh() {
        recent = Remembered.visits()
        faces = Remembered.visitFaces()
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
        guard Rehearsal.measuresTheSearchPage else { return }
        if Rehearsal.opensKeyboard { isFocused = true }
        Task {
            // After the keyboard, not before it. The window that would change
            // any of this does not exist until it is on screen.
            try? await Task.sleep(for: .seconds(2))
            NSLog(
                "Quiet: top %.1f, page at %.1f, field at %.1f, keyboard %@",
                Double(SafeArea.top), Double(whereIAm), Double(whereTheFieldIs),
                Rehearsal.opensKeyboard ? "up" : "down"
            )
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
            if !query.isEmpty {
                Button {
                    query = ""
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
#if DEBUG
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { whereTheFieldIs = proxy.frame(in: .global).minY }
                    .onChange(of: proxy.frame(in: .global).minY) { whereTheFieldIs = $1 }
            }
        )
#endif
    }

    /// Whoever is left once the field has narrowed the list, and then the name
    /// as it was typed.
    ///
    /// The typed name is last rather than first on purpose. Somebody typing
    /// three letters is far more often reaching for a person they already open
    /// than for a stranger, and a row that jumps to the top on every keystroke
    /// is a row you tap by accident.
    ///
    /// It is put through `ContentRules.profile(forHandle:)` first, so what is
    /// matched and what is opened are the same string: an `@` in front and a
    /// pasted profile link both come out as the bare handle, and anything that
    /// is not a plausible handle comes out as nothing and offers no row.
    private var narrowed: [String] { Self.narrowing(query, among: recent) }

    /// Written as a function of its two inputs so it can be asked questions
    /// without a screen — `RecentsTests`. What replaced a request to Instagram
    /// is worth more than a comment saying it behaves.
    ///
    /// `nonisolated` because it is true: it reads no state of this view and
    /// touches nothing on the glass. A pure function of a string and a list.
    nonisolated static func narrowing(_ query: String, among recent: [String]) -> [String] {
        let typed = ContentRules.profile(forHandle: query)
            .flatMap { ContentRules.pathComponents(of: $0).first }
        let needle = typed ?? query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return recent }

        var found = recent.filter { $0.contains(needle) }
        if let typed, !found.contains(typed) { found.append(typed) }
        return found
    }

    @ViewBuilder
    private var narrowedRows: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(narrowed, id: \.self) { handle in
                    Button {
                        open(handle)
                    } label: {
                        HStack(spacing: 13) {
                            face(faces[handle], of: handle, at: 44)
                            Text(handle)
                                .font(.quietBody)
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
                    faces = [:]
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
                        face(faces[handle], of: handle, at: 32)
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
    /// The photographs used to be fetched for eight names at once from
    /// `/api/v1/users/web_profile_info/`. They come off the profile page itself
    /// now, at the moment somebody opens it — `faceOnThisProfile` in `trim.js`
    /// — which is the same picture, from a page the reader asked for, and it
    /// costs no request of the app's own.
    ///
    /// A picture that is not there yet is not worth an error or an empty ring:
    /// the first letter of the name, set on paper, is a perfectly good way to
    /// tell six rows apart. It is a stand-in and not a style, which is why the
    /// two lists on this screen share it rather than each having their own.
    private func face(_ picture: UIImage?, of handle: String, at side: CGFloat) -> some View {
        Group {
            if let picture {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Paper.ink.opacity(0.08))
                    .frame(width: side, height: side)
                    .overlay(
                        Text(String(handle.prefix(1)).uppercased())
                            .font(side < 40 ? .quietSmall : .quietBody)
                            .foregroundStyle(Paper.inkSoft)
                    )
            }
        }
        // The picture says nothing the name beside it does not, and a row that
        // reads out "photo, ada" is a row that takes twice as long to hear.
        .accessibilityHidden(true)
    }

    /// The one sentence under the field.
    ///
    /// It used to be four, one per state of a request that no longer happens.
    /// There is no request, so there is no waiting, no empty answer and no
    /// endpoint that has stopped replying — which is three fewer things that
    /// can go wrong in front of somebody and three fewer sentences to keep true
    /// in six languages.
    private var explanation: String {
        String(localized: "Type a name and press search. Quiet opens that profile and nothing else — no Explore, no hashtags, no places.")
    }

    /// The return key: go to exactly what was typed, which is what somebody who
    /// already knows the name expects.
    private func exactly() {
        open(query)
    }

    /// Nothing is opened for something that is not a plausible handle, which is
    /// the whole of the validation and it belongs in `ContentRules`: a name is
    /// an address here, and what counts as one is the same question the router
    /// answers about every other link in the app.
    private func open(_ handle: String) {
        guard let url = ContentRules.profile(forHandle: handle) else { return }
        // The name as the app will use it, rather than as it was typed: a
        // pasted link and an @ in front of it are the same person.
        if let name = ContentRules.pathComponents(of: url).first {
            Remembered.remember(visit: name)
            recent = Remembered.visits()
            faces = Remembered.visitFaces()
        }
        onOpen(url)
    }
}
