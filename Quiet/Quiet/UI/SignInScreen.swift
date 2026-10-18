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

    var body: some View {
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
