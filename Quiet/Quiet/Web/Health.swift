import Foundation

/// Whether the trim pass is still finding anything.
///
/// The maintenance cost of this whole approach, written down as a number.
///
/// `ContentRules` matches on addresses and will go on working: Reels and
/// Explore are refused because of where they are, and Instagram cannot rename
/// its way out of that. Everything else — the row along the bottom, the header,
/// the blocks with no address of their own — is found by shape, and the day the
/// shape changes the finding stops. Nothing throws. Nothing is logged. The row
/// quietly falls back to Quiet's own symbols and the suggestions quietly come
/// back, and the app goes on looking exactly like an app that is working.
///
/// That is the failure this exists to give a voice to. It cannot mend anything.
/// It can turn "somebody eventually notices while scrolling" into a sentence in
/// the panel, which is the difference between a bug that gets reported and one
/// that does not.
struct Health: Equatable, Sendable {
    /// Pages that have been opened this run.
    var pages = 0
    /// How many of them Instagram's own navigation row was found on.
    var nav = 0
    /// How many of them its header was found on. Only the feed has one, so a
    /// low number here is ordinary and is not read as a fault.
    var headers = 0
    /// Blocks hidden this run, counted once each.
    var hidden = 0

    /// How many pages must go by before silence means anything.
    ///
    /// One page proves nothing: the login screen carries no navigation, nor
    /// does a story, nor a conversation. Five pages without a single row found
    /// is not a page without one — it is a shape that has changed.
    static let patience = 5

    /// True when enough has been seen to say that the recognising has stopped
    /// working.
    var hasLostTheShape: Bool {
        pages >= Self.patience && nav == 0
    }

    /// Built from what the page sent, ignoring anything malformed.
    ///
    /// Its own initialiser rather than a `Decodable` conformance because the
    /// message arrives as a dictionary from JavaScript, where every number is
    /// an `NSNumber` and any of the four keys can simply be absent.
    init(pages: Int = 0, nav: Int = 0, headers: Int = 0, hidden: Int = 0) {
        self.pages = pages
        self.nav = nav
        self.headers = headers
        self.hidden = hidden
    }

    init?(message body: [String: Any]) {
        func count(_ key: String) -> Int? {
            guard let number = body[key] as? NSNumber else { return nil }
            let value = number.intValue
            return value >= 0 ? value : nil
        }
        guard let pages = count("pages"), let nav = count("nav"),
              let headers = count("headers"), let hidden = count("hidden") else {
            return nil
        }
        // A tally only ever climbs, and the page counts pages before it counts
        // what was found on them. More rows than pages is not a reading.
        guard nav <= pages, headers <= pages else { return nil }
        self.init(pages: pages, nav: nav, headers: headers, hidden: hidden)
    }
}
