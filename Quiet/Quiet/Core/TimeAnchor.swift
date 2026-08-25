import Foundation

/// A moment somebody other than this phone vouched for.
///
/// Quiet has no server, and for a long time that meant one half of the clock
/// was simply open: turning the date *back* was caught, and turning it
/// *forward* bought a whole fresh day for the price of two taps in Settings.
/// The trade was written down honestly in the trade-offs and left there.
///
/// It does not have to be. The app already talks to a machine that knows what
/// time it is — every page it loads comes back with a `Date` header on it, put
/// there by Instagram's own servers. That is not a service Quiet asks anyone
/// for and not a request it makes on its own; it is a line that was already in
/// an answer the app was already reading. It costs nothing and it is enough.
///
/// The anchor pairs that instant with the device's *uptime* at the moment it
/// arrived, and uptime is the one clock a settings screen cannot touch: it
/// counts from the last restart and it includes the hours the phone spent
/// asleep. So within a single boot, "how much real time has passed since the
/// anchor" is arithmetic rather than a question — and the wall clock can be
/// moved anywhere it likes without the answer changing.
struct TimeAnchor: Equatable, Sendable {
    /// What the other party said the time was.
    let instant: Date

    /// The device's uptime at the moment that was heard.
    let uptime: TimeInterval

    /// What the time is now, counted forward from the anchor by real elapsed
    /// time rather than by anything the device claims about the date.
    func now(at current: TimeInterval) -> Date {
        instant.addingTimeInterval(current - uptime)
    }
}

/// Reading the one line of an HTTP response that says what time it is.
///
/// Its own type so that the parsing can be tested without a web view, and so
/// that the formatter — which is expensive to build and must never pick up the
/// reader's own locale or time zone — is built once.
enum ServerDate {
    /// RFC 9110's preferred form, which is what every server actually sends:
    /// `Sun, 06 Nov 1994 08:49:37 GMT`.
    ///
    /// Fixed to POSIX and to GMT on purpose. A formatter that inherits the
    /// device's locale reads that string as nonsense on a phone set to Arabic
    /// numerals, and one that inherits the device's time zone would fold the
    /// very error this exists to catch straight back into the answer.
    private static let reader: DateFormatter = {
        let reader = DateFormatter()
        reader.locale = Locale(identifier: "en_US_POSIX")
        reader.timeZone = TimeZone(secondsFromGMT: 0)
        reader.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return reader
    }()

    static func parse(_ header: String?) -> Date? {
        guard let header else { return nil }
        return reader.date(from: header.trimmingCharacters(in: .whitespaces))
    }

    /// The `Date` header out of a response, if this is a response worth
    /// believing.
    ///
    /// Only Instagram's own hosts, and only over HTTPS. A header read off a
    /// plain-text response from anywhere at all would be a clock anybody on the
    /// network could set.
    static func vouched(by response: HTTPURLResponse) -> Date? {
        guard let url = response.url,
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              ContentRules.isInternal(host: host) else { return nil }
        return parse(response.value(forHTTPHeaderField: "Date"))
    }
}
