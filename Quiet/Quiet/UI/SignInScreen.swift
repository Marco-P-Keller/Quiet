import SwiftUI

/// Signing in, on a page with an address above it.
///
/// The browsing screen deliberately has no address bar, and for reading a feed
/// that is right. For typing a password it is the one thing missing: a sign-in
/// form inside somebody else's app, with nothing saying whose page it is, is
/// exactly what a phishing app looks like. So for as long as somebody is
/// signing in, the app shows what Safari would — the host, and a padlock when
/// the page arrived encrypted — drawn by the app, above the page and outside
/// it, where nothing the page does can reach or imitate it.
///
/// Underneath is `SignInWebView`, which carries no script of Quiet's at all.
/// The sentence under the address says so, and that file is where it is true.
struct SignInScreen: View {
    let start: URL
    /// Whether there is a session behind this screen to go back to.
    let canLeave: Bool
    let session: QuietSession
    let surface: WebSurface
    let topInset: CGFloat

    @State private var page = SignInPage()

    /// Whether the page before the page has been read.
    ///
    /// Only somebody with no session is shown it. Somebody who is already
    /// signed in and came here for a password or Accounts Center has signed in
    /// through this screen before, and a second reading of the same sentences
    /// in front of a form they asked for is a toll gate.
    @State private var hasRead: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(start: URL, canLeave: Bool, session: QuietSession, surface: WebSurface, topInset: CGFloat) {
        self.start = start
        self.canLeave = canLeave
        self.session = session
        self.surface = surface
        self.topInset = topInset
        _hasRead = State(initialValue: canLeave)
    }

    var body: some View {
        ZStack {
            signingIn

            // Over the page rather than before it, so that Instagram is loading
            // while the sentences are read and the form is there on the tap.
            if !hasRead {
                SignInExplained(topInset: topInset) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { hasRead = true }
                }
                .transition(.opacity)
            }
        }
    }

    private var signingIn: some View {
        VStack(spacing: 0) {
            strip
                .frame(maxWidth: .infinity)
                .padding(.top, topInset)
                .background(Paper.page)

            Rectangle()
                .fill(Paper.rule)
                .frame(height: 1 / UIScreen.main.scale)

            SignInWebView(
                start: start,
                page: page,
                session: session,
                surface: surface,
                onFinish: { surface.signInIsOver() }
            )
            // To the bottom edge. The web view keeps its own page clear of the
            // home indicator, the way it does in Safari, and a band of the
            // app's colour under a page that is dimmed for a dialog is a seam.
        }
        .background(Paper.ground)
    }

    private var strip: some View {
        VStack(spacing: 3) {
            ZStack {
                address
                    .padding(.horizontal, 64)

                if canLeave {
                    HStack {
                        Spacer(minLength: 0)
                        Button("Done") { surface.leaveSignIn() }
                            .font(.quietAction)
                            .foregroundStyle(Paper.ink)
                    }
                }
            }

            Text("Quiet runs no code on this page.")
                .font(.quietFine)
                .foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    /// The host and the padlock, the way Safari sets them: small, centred, and
    /// nothing else on the line.
    private var address: some View {
        HStack(spacing: 5) {
            Image(systemName: page.isSecure ? "lock.fill" : "lock.open")
                .font(.quietSmall)
                .accessibilityLabel(page.isSecure ? Text("Secure connection") : Text("Not a secure connection"))
            if let host = page.host {
                Text(verbatim: host)
                    .font(.quietBody.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .foregroundStyle(Paper.ink)
        .accessibilityElement(children: .combine)
    }
}

/// The page before the sign-in: what is about to happen, and how to check it
/// without taking Quiet's word for anything.
///
/// Two of the sentences send the reader somewhere else on purpose. A promise
/// made by the app about the app is worth what the app is worth; the two
/// places named here belong to Apple and to Instagram, and either of them
/// would show it if Quiet were lying. Both paths were read off the vendors'
/// own help pages in all six languages on 2026-10-18 — Apple's article 102188
/// and Instagram's 2761108904184084 — rather than written from memory, because
/// a menu name that does not exist is the one way this page could make
/// somebody trust it less.
///
/// The report has to be switched on before it records anything, and it says
/// so. Apple counts what a web view inside an app fetches as that app's
/// network activity, which is what makes it the right witness here.
private struct SignInExplained: View {
    let topInset: CGFloat
    var onContinue: () -> Void

    var body: some View {
        // Scrolls, for the same reason the setup screens do: at the largest
        // text sizes these five sentences are taller than the glass.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("You sign in with Instagram itself.")
                    .font(.quietHeading)
                    .lineSpacing(5)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 14) {
                    Line("The next page is Instagram's own sign-in, with its address shown above it.")
                    Line("Quiet does not read your password, does not keep it and sends it nowhere. It runs no code on that page and has no server of its own.")
                    Line("Check it on your iPhone: Settings › Privacy & Security › App Privacy Report lists every address Quiet contacts, once you turn the report on.")
                    Line("Afterwards, in Instagram: Accounts Center › Password and security › Where you're logged in shows this sign-in, and you can end it there at any time.")
                    Line("Safer still: turn on two-factor authentication in Instagram. Then a password on its own is of no use to anyone.")
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, topInset + 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            QuietButton(title: String(localized: "Continue to Instagram"), action: onContinue)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 20 + SafeArea.bottom)
                .background(Paper.page)
        }
        .quietPage()
    }

    /// One sentence, set the way the setup screens set them.
    private struct Line: View {
        let key: LocalizedStringKey
        init(_ key: LocalizedStringKey) { self.key = key }

        var body: some View {
            Text(key)
                .font(.quietNote)
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
