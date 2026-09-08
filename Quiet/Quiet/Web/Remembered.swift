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
    private static let visitedFaces = "quiet.visited.faces"

    /// How big a kept face is, in pixels on a side. See `thumbnail`.
    private static let faceSide: CGFloat = 96

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

    /// Their faces, keyed by the same name.
    ///
    /// A list of eight names is a spreadsheet, and finding a friend is
    /// something people do by recognising them — which is the argument the
    /// search results already won, and there was never a reason the list you
    /// see *before* you type should be the poorer of the two.
    ///
    /// Kept beside the names rather than fetched when the page opens, for the
    /// same reason the glyphs are: a list that is right in its first frame and
    /// a list that corrects itself a second later are different lists, and only
    /// one of them looks like an app that knows who you are.
    static func visitFaces(defaults: UserDefaults = .standard) -> [String: UIImage] {
        guard let stored = defaults.dictionary(forKey: visitedFaces) as? [String: Data] else {
            return [:]
        }
        return stored.compactMapValues(UIImage.init(data:))
    }

    /// Note that a profile was opened.
    ///
    /// Moved to the front rather than added, so somebody's own three or four
    /// people stay at the top instead of being pushed off by an afternoon of
    /// looking at strangers.
    ///
    /// The face is optional because half of the ways in here have one and half
    /// do not: opening somebody out of the search results means their picture
    /// is already in hand, and typing a name and pressing return means it is
    /// not. What comes without one keeps whatever was known before.
    static func remember(
        visit handle: String,
        face picture: UIImage? = nil,
        defaults: UserDefaults = .standard
    ) {
        let name = handle.lowercased()
        guard !name.isEmpty else { return }
        var names = visits(defaults: defaults)
        names.removeAll { $0 == name }
        names.insert(name, at: 0)
        let kept = Array(names.prefix(howMany))
        defaults.set(kept, forKey: visited)

        var faces = stored(defaults: defaults)
        if let picture, let small = thumbnail(picture) {
            faces[name] = small
        }
        // Nobody's face outlives their name. Without this the store is the one
        // thing on the list that is a history — everybody this phone has ever
        // opened, kept as a photograph, long after the name was pushed off.
        keep(faces.filter { kept.contains($0.key) }, defaults: defaults)
    }

    /// A face for somebody already on the list, learned after the fact.
    ///
    /// Somebody who was opened by name has no picture at the moment they are
    /// opened; the page can be asked for one afterwards, and this is where the
    /// answer goes. Refused for anybody not on the list, so a late answer about
    /// somebody who has since been pushed off cannot put them back.
    static func remember(
        face picture: UIImage,
        for handle: String,
        defaults: UserDefaults = .standard
    ) {
        let name = handle.lowercased()
        guard visits(defaults: defaults).contains(name), let small = thumbnail(picture) else {
            return
        }
        var faces = stored(defaults: defaults)
        guard faces[name] != small else { return }
        faces[name] = small
        keep(faces, defaults: defaults)
    }

    static func forgetVisits(defaults: UserDefaults = .standard) {
        [visited, visitedFaces].forEach(defaults.removeObject(forKey:))
    }

    private static func stored(defaults: UserDefaults) -> [String: Data] {
        defaults.dictionary(forKey: visitedFaces) as? [String: Data] ?? [:]
    }

    private static func keep(_ faces: [String: Data], defaults: UserDefaults) {
        defaults.set(faces, forKey: visitedFaces)
    }

    /// The picture, cut down to the size it is actually drawn at.
    ///
    /// Instagram hands back a profile picture that can be three hundred
    /// kilobytes, and the list draws it at thirty-two points. Eight of those
    /// kept whole would be two megabytes of somebody else's photographs sitting
    /// in `UserDefaults` to be read on every launch, which is the difference
    /// between a cache and a hoard. At ninety-six pixels — a retina thirty-two
    /// — eight of them together are smaller than one of them was.
    ///
    /// Filled rather than squashed, because Instagram's are square and anything
    /// that is not should lose its edges rather than its proportions. A face
    /// that has been stretched is worse than a face that has been cropped.
    private static func thumbnail(_ picture: UIImage) -> Data? {
        let wide = picture.size.width
        let tall = picture.size.height
        guard wide > 0, tall > 0 else { return nil }

        let side = CGSize(width: faceSide, height: faceSide)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let square = UIGraphicsImageRenderer(size: side, format: format).image { _ in
            let scale = max(faceSide / wide, faceSide / tall)
            let drawn = CGSize(width: wide * scale, height: tall * scale)
            picture.draw(
                in: CGRect(
                    x: (faceSide - drawn.width) / 2,
                    y: (faceSide - drawn.height) / 2,
                    width: drawn.width,
                    height: drawn.height
                )
            )
        }
        return square.jpegData(compressionQuality: 0.8)
    }

    /// Who this phone is signed in as, and their face.
    ///
    /// Not the glyphs, which are Instagram's own icons and the same for
    /// everybody, and not the people this phone opens, which belong to the
    /// phone rather than to an account. Only the two things that are somebody:
    /// left behind, they are the last person's name and the last person's
    /// photograph, drawn into the row on the next launch before any page has
    /// said otherwise.
    static func forgetMe(defaults: UserDefaults = .standard) {
        [name, face].forEach(defaults.removeObject(forKey:))
    }

    /// For a rehearsal, so that a scene photographs the same app every time.
    static func forget(defaults: UserDefaults = .standard) {
        [glyphs, name, face, visited, visitedFaces].forEach(defaults.removeObject(forKey:))
    }
}
