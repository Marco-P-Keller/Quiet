import Foundation

/// The surfaces Quiet removes.
///
/// Each one exists to hand you something you did not ask for. The feed, stories,
/// messages and profiles are things you went looking for; these are not.
enum BlockedSurface: String, Codable, Sendable {
    case reels
    case explore
    /// Instagram's own app, offered by its own pages as a way out of here.
    case theApp

    /// Shown for a moment when a link into one of these is tapped. Silence would
    /// read as a broken app; an apology would read as an accident. Neither is
    /// true, so the app just says what it did.
    var message: String {
        switch self {
        case .reels: return "Reels are off in Quiet."
        case .explore: return "Explore is off in Quiet."
        case .theApp: return "Quiet is your Instagram here."
        }
    }
}

/// What to do with a page the web view is about to open.
enum Routing: Equatable, Sendable {
    /// Load it.
    case allow
    /// Refuse, and say why.
    case refuse(BlockedSurface)
    /// Not Instagram. Hand it to the system so Quiet stays one app, not a
    /// browser with an Instagram bookmark.
    case openOutside
}

/// Which addresses Quiet will open, and which it will not.
///
/// Deciding by URL rather than by what the page looks like is the load-bearing
/// half of the app: it is the one layer that cannot be defeated by Instagram
/// renaming a CSS class. The cosmetic layer in `trim.css` tidies up what this
/// leaves behind.
enum ContentRules {
    /// Domains that stay inside the app. Instagram itself, and the Meta login
    /// domains that an Instagram sign-in legitimately passes through — bouncing
    /// those to Safari would break logging in.
    static let internalDomains: Set<String> = [
        "instagram.com",
        "cdninstagram.com",
        "facebook.com",
        "fbcdn.net",
        "meta.com",
    ]

    /// The first path component of every surface Quiet removes.
    ///
    /// Matched on whole components rather than on a string prefix, so that a
    /// person whose username happens to begin with "reels" is still reachable.
    static let blockedRoots: [String: BlockedSurface] = [
        "reels": .reels,
        "reel": .reels,
        "explore": .explore,
        "directory": .explore,
    ]

    static func routing(for url: URL) -> Routing {
        guard let scheme = url.scheme?.lowercased() else { return .openOutside }

        // WebKit's own internals. Never a page a person chose to visit.
        if scheme == "about" || scheme == "data" || scheme == "blob" {
            return .allow
        }

        // Instagram's pages carry a button that opens Instagram's own app.
        // Handing that to the system would walk someone straight back into the
        // thing they installed this to get away from — one tap, no limit, all
        // the Reels. It is the only door out that Instagram builds itself, and
        // the only reason to refuse a link the person deliberately tapped.
        if scheme == "instagram" || scheme == "instagram-stories" {
            return .refuse(.theApp)
        }

        guard scheme == "http" || scheme == "https" else { return .openOutside }
        guard let host = url.host?.lowercased(), isInternal(host: host) else { return .openOutside }

        let components = pathComponents(of: url)
        guard let first = components.first else { return .allow }

        if let surface = blockedRoots[first] {
            return .refuse(surface)
        }
        if first == "accounts", components.dropFirst().first == "suggested" {
            return .refuse(.explore)
        }
        // The Reels tab on a profile: /someone/reels/. Someone's own reels are
        // still the reels player, and the promise was that it is gone.
        if components.dropFirst().first == "reels" {
            return .refuse(.reels)
        }
        return .allow
    }

    /// Lower-cased, empty components dropped, so matching does not depend on how
    /// a link happened to be written.
    static func pathComponents(of url: URL) -> [String] {
        url.path.lowercased().split(separator: "/").map(String.init)
    }

    /// True when `host` is one of the internal domains, or a subdomain of one.
    static func isInternal(host: String) -> Bool {
        internalDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Where the app opens, and where the home button goes.
    static let home = URL(string: "https://www.instagram.com/")!

    /// The profile page for a handle typed into "Find someone". Returns `nil`
    /// for anything that is not a plausible Instagram username, rather than
    /// sending the person to a 404.
    static func profile(forHandle raw: String) -> URL? {
        var handle = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if handle.hasPrefix("@") { handle.removeFirst() }

        // Tolerate a pasted profile link, with or without a scheme, because that
        // is what people have on the clipboard.
        if handle.contains("/") {
            let candidate = handle.contains("://") ? handle : "https://" + handle
            guard let url = URL(string: candidate),
                  let host = url.host?.lowercased(), isInternal(host: host),
                  let first = pathComponents(of: url).first else { return nil }
            handle = first
        }

        guard !handle.isEmpty, handle.count <= 30 else { return nil }
        let permitted = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")
        guard handle.unicodeScalars.allSatisfy({ permitted.contains($0) }) else { return nil }
        return URL(string: "https://www.instagram.com/\(handle)/")
    }
}
