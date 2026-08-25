import UIKit

/// What the row along the bottom already knew last time.
///
/// Quiet's row is drawn with Instagram's own glyphs, read out of Instagram's
/// own navigation once a page has loaded — which is honest, and which took
/// about a second. For that second the row stood there wearing the symbols
/// Quiet falls back to, and then every one of them changed at once. The app
/// looked like it was correcting itself in front of you.
///
/// The fix is not to draw them faster. It is to notice that a house and a
/// paper plane are the same this morning as they were last night, and that an
/// app which has seen them once has no business asking again before it can
/// show anything. So they are kept, and the row is right in its first frame.
///
/// Kept in `UserDefaults` rather than the keychain on purpose. The keychain
/// holds the one thing that must outlive a reinstall — the limit — and putting
/// a cache of pictures beside it would be putting a convenience where a promise
/// lives. Losing all of this costs a second, once.
///
/// Nothing here is a secret: the glyphs are on Instagram's own page, and the
/// name and face are the ones drawn in Quiet's own row a moment later. Deleting
/// the app takes them with it.
enum Remembered {
    private static let glyphs = "quiet.glyphs"
    private static let name = "quiet.me.name"
    private static let face = "quiet.me.face"

    /// Small on purpose. The glyphs are 96-point squares with two colours in
    /// them; a page that started handing back photographs would be refused
    /// rather than trusted, one at a time.
    private static let biggest = 64 * 1024

    // MARK: - Instagram's glyphs

    /// Keyed the way `WebSurface` keys them: "home.on", "messages.off".
    static func icons(defaults: UserDefaults = .standard) -> [String: UIImage] {
        guard let stored = defaults.dictionary(forKey: glyphs) as? [String: Data] else {
            return [:]
        }
        var drawn: [String: UIImage] = [:]
        for (entry, data) in stored {
            guard let image = UIImage(data: data) else { continue }
            drawn[entry] = image.withRenderingMode(.alwaysTemplate)
        }
        return drawn
    }

    static func remember(icon entry: String, data: Data, defaults: UserDefaults = .standard) {
        guard data.count <= biggest else { return }
        var stored = defaults.dictionary(forKey: glyphs) as? [String: Data] ?? [:]
        guard stored[entry] != data else { return }
        stored[entry] = data
        defaults.set(stored, forKey: glyphs)
    }

    // MARK: - Who is signed in

    static func me(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: name)
    }

    static func myFace(defaults: UserDefaults = .standard) -> UIImage? {
        guard let data = defaults.data(forKey: face) else { return nil }
        return UIImage(data: data)
    }

    static func remember(
        me who: String,
        face picture: Data?,
        defaults: UserDefaults = .standard
    ) {
        if defaults.string(forKey: name) != who {
            defaults.set(who, forKey: name)
        }
        guard let picture, picture.count <= biggest else { return }
        if defaults.data(forKey: face) != picture {
            defaults.set(picture, forKey: face)
        }
    }

    // MARK: - Who you actually go and see

    private static let visited = "quiet.visited"

    /// How many names are kept.
    ///
    /// Short on purpose, and the shortness is the design. This is not a
    /// history: a list of everybody you have looked at, in order, with dates,
    /// is one more thing to scroll and one more thing to feel something about.
    /// It is a shortcut to the handful of people somebody opens the app to see,
    /// which for almost everybody is fewer than this.
    private static let howMany = 8

    /// The names most recently opened, newest first.
    static func visits(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: visited) ?? []
    }

    /// Note that a profile was opened.
    ///
    /// Moved to the front rather than added, so somebody's own three or four
    /// people stay at the top instead of being pushed off by an afternoon of
    /// looking at strangers.
    static func remember(visit handle: String, defaults: UserDefaults = .standard) {
        let name = handle.lowercased()
        guard !name.isEmpty else { return }
        var names = visits(defaults: defaults)
        names.removeAll { $0 == name }
        names.insert(name, at: 0)
        defaults.set(Array(names.prefix(howMany)), forKey: visited)
    }

    static func forgetVisits(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: visited)
    }

    /// For a rehearsal, so that a scene photographs the same app every time.
    static func forget(defaults: UserDefaults = .standard) {
        [glyphs, name, face, visited].forEach(defaults.removeObject(forKey:))
    }
}
