import SwiftUI

/// What is on screen when the page did not arrive at all.
///
/// The app used to show whatever WebKit shows, which on an iPhone with no
/// signal is a small grey sentence in Helvetica, centred in a white rectangle,
/// under a row that Quiet drew. Nothing about it is wrong except that it is
/// visibly not part of the app — and the one moment somebody is most likely to
/// think an app is broken is the moment it shows them somebody else's error.
///
/// So this is paper, like the other three screens Quiet owns, and it says the
/// two things worth saying: what happened, and that there is a button.
struct StumbleView: View {
    enum Kind: Equatable, Sendable {
        /// Nothing to reach the network with.
        case offline
        /// Something else. Deliberately not diagnosed further: the codes WebKit
        /// hands back are about DNS and TLS and sockets, and none of them turn
        /// into a sentence that helps anybody holding a phone.
        case unreachable
    }

    let kind: Kind
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text(headline)
                .font(.quietTitle)
                .fixedSize(horizontal: false, vertical: true)

            Text(explanation)
                .font(.quietNote)
                .foregroundStyle(Paper.inkSoft)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            QuietButton(title: String(localized: "Try again"), action: onRetry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .quietPage()
    }

    private var headline: String {
        switch kind {
        case .offline: return String(localized: "No connection.")
        case .unreachable: return String(localized: "Instagram did not answer.")
        }
    }

    private var explanation: String {
        switch kind {
        case .offline:
            return String(localized: "Quiet shows Instagram's own site, so it needs the network to show you anything. Nothing has been lost — your day and your limit are on this phone.")
        case .unreachable:
            return String(localized: "The page did not arrive. That is usually a moment rather than a problem.")
        }
    }
}

#Preview("Offline") {
    StumbleView(kind: .offline, onRetry: {})
}

#Preview("Unreachable") {
    StumbleView(kind: .unreachable, onRetry: {})
}
