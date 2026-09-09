import Foundation
import Observation

/// The two shapes the row along the bottom can have.
///
/// Instagram draws a bar: the full width of the glass, flush against the bottom
/// edge, opaque, a hairline above it. Quiet drew an island for a while — a pill
/// inset from both edges, floating over the page, drawing itself in as the page
/// moved. Neither is wrong. The bar is what the app being imitated does; the
/// island is the nicer object, and it is the one that was asked for first.
///
/// So it is a choice rather than an argument, and the only choice in the app
/// that is purely about how something looks.
enum RowShape: String, CaseIterable, Sendable {
    /// Instagram's own: full width, flush, opaque.
    case bar
    /// A floating pill, inset from both edges, with the page running under it.
    case island

    var name: String {
        switch self {
        case .bar: return String(localized: "Bar")
        case .island: return String(localized: "Island")
        }
    }

    /// The shape the app opens with, before anybody has chosen one.
    ///
    /// The island is the shape the app was asked for first, and on a phone with
    /// a cutout in the glass running a system that draws in that idiom it is
    /// the one that looks like it belongs there. On an iPhone 14 or older, or
    /// on a system older than iOS 26, the same pill is a floating object with
    /// nothing above it to answer to, so the app opens as Instagram's own bar
    /// instead — which is also the honest first impression of an app that is
    /// showing Instagram.
    ///
    /// Either way this is only a starting point. The panel offers both shapes
    /// on every phone, and a choice made there outlives this rule.
    static func standard(on hardware: Hardware = .current) -> RowShape {
        hardware.isIPhone15OrNewer && hardware.systemMajorVersion >= 26 ? .island : .bar
    }
}

/// What the island does while the page moves under it.
///
/// Two answers were built and neither turned out to be wrong, which is the same
/// place `RowShape` ended up and the same reason this is a choice rather than an
/// argument.
///
/// The pill used to draw itself in — smaller and paler, in place — and come back
/// out after a tenth of a second of stillness. That reads well on one long
/// scroll and badly on the way a feed is actually read, which is a flick, a
/// pause to look at a post, a flick: the row shrank and popped back on every one
/// of those pauses, and the thing meant to get out of the way became the only
/// moving object on the screen.
///
/// So the default is Instagram's rule instead — down hides it, up brings it
/// back, holding still does nothing — and the older one is kept, because "the
/// row never actually leaves" is a real preference to hold and the argument for
/// it was never wrong, only outvoted.
enum RowMotion: String, CaseIterable, Sendable {
    /// Off the bottom edge and back. Instagram's own, and the default.
    case leaves
    /// Smaller and paler in place, back out when the page holds still.
    case drawsIn

    var name: String {
        switch self {
        case .leaves: return String(localized: "Slides away")
        case .drawsIn: return String(localized: "Draws in")
        }
    }
}

/// The handful of things that are about how Quiet looks rather than what it
/// promises.
///
/// Deliberately not kept where the limit is. The limit lives in the keychain
/// because it has to outlive the app being deleted — that is the whole promise,
/// and the About screen says so in as many words. A preference about the shape
/// of a row surviving a delete-and-reinstall would be a surprise rather than a
/// feature, so it lives in the ordinary place preferences live.
/// Where the choice is kept. At file scope so that a rehearsal can set it
/// without stepping onto the main actor to do it.
private enum Key {
    static let row = "quiet.row.shape"
    static let rowMotion = "quiet.row.motion"
    static let saysWhatIsLeft = "quiet.says.what.is.left"
    static let showsSuggestions = "quiet.shows.suggestions"
    static let appointmentIsOn = "quiet.appointment.on"
    static let appointmentAt = "quiet.appointment.at"
    static let carriesBetweenDevices = "quiet.carries.between.devices"
    static let recapIsOn = "quiet.recap.on"
    static let recapAt = "quiet.recap.at"
    /// Whether the phone has been asked about the morning note yet. Not the
    /// answer — iOS keeps that — only whether the question has been put, so it
    /// is put once and never again.
    static let recapAsked = "quiet.recap.asked"
}

@MainActor
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    /// What the hardware asks for to begin with: the island on an iPhone 15 or
    /// newer running iOS 26 or newer, Instagram's own bar everywhere else.
    var row: RowShape {
        didSet {
            guard row != oldValue else { return }
            defaults.set(row.rawValue, forKey: Key.row)
        }
    }

    /// What the island does while the page moves under it. See `RowMotion`.
    ///
    /// Nothing to do with `row` beyond applying only to one of its two values:
    /// a bar standing on the bottom edge has nothing to float over and nothing
    /// to get out of the way of, so it never moves whatever this says.
    var rowMotion: RowMotion {
        didSet {
            guard rowMotion != oldValue else { return }
            defaults.set(rowMotion.rawValue, forKey: Key.rowMotion)
        }
    }

    /// Whether the app says anything as the day runs out.
    ///
    /// On by default, and the default is the considered answer: a screen that
    /// replaces itself with no warning reads as a fault, and two quiet notices
    /// are the smallest thing that stops the end of the day being a surprise.
    ///
    /// It can be turned off, and that is not a hole in the rule. Nothing about
    /// a warning changes how much time there is — the limit is the limit
    /// whether or not anybody is counted down to it — and for some people a
    /// notice saying five minutes remain is precisely the thing that starts a
    /// last five minutes. The one argument the app refuses to have is about
    /// *how much*; this is not that argument.
    var saysWhatIsLeft: Bool {
        didSet {
            guard saysWhatIsLeft != oldValue else { return }
            defaults.set(saysWhatIsLeft, forKey: Key.saysWhatIsLeft)
        }
    }

    /// Whether Instagram's suggested posts are shown, which they are.
    ///
    /// The app used to take every one of them out and that was not a setting.
    /// It is one now, and it is on: the feed you are shown is the feed the site
    /// would show you, and somebody who would rather read only the people they
    /// chose can say so here.
    ///
    /// Which way round the default goes is the whole of the decision, and it
    /// goes this way because the other way is the app quietly editing what a
    /// person's friends and the site sent them without ever having been asked
    /// to. A switch is an answer to that. A default is not.
    ///
    /// It is about suggestions and nothing else. Reels are refused by address
    /// in three places and a block of them in the feed goes either way — a
    /// promise the app makes elsewhere is not something a setting about
    /// suggested posts gets to undo. See `REELS_LABELS` in trim.js.
    var showsSuggestions: Bool {
        didSet {
            guard showsSuggestions != oldValue else { return }
            defaults.set(showsSuggestions, forKey: Key.showsSuggestions)
        }
    }

    /// The daily reminder: whether it rings, and at what hour.
    ///
    /// A preference rather than a promise, so it lives here with the others
    /// and not in the keychain. Somebody who deletes the app and installs it
    /// again keeps their limit, because that is the promise — and gets asked
    /// about the reminder again, because a notification arranging itself
    /// behind a fresh install would be a surprise.
    var appointment: Appointment {
        didSet {
            guard appointment != oldValue else { return }
            defaults.set(appointment.isOn, forKey: Key.appointmentIsOn)
            defaults.set(appointment.minutesAfterMidnight, forKey: Key.appointmentAt)
        }
    }

    /// The morning note about the days behind you: whether it arrives, and at
    /// what hour.
    ///
    /// A separate switch from the appointment, and not for tidiness. The two
    /// are opposite errands — one is an invitation to a window that is open,
    /// the other is an account of a window that has closed — and somebody who
    /// wants to be told what a week came to may want nothing at all telling
    /// them Instagram is available. Bundled together, the account could only
    /// be had by also buying the invitation.
    var recap: Recap {
        didSet {
            guard recap != oldValue else { return }
            defaults.set(recap.isOn, forKey: Key.recapIsOn)
            defaults.set(recap.minutesAfterMidnight, forKey: Key.recapAt)
        }
    }

    /// Whether the limit, the wait and today's total follow you to your other
    /// devices through iCloud.
    ///
    /// Off until asked for, like everything else here. It is the only setting
    /// in the app that sends anything anywhere, and a thing that leaves the
    /// phone should be a thing somebody switched on rather than a thing they
    /// were opted into — even when the somewhere is their own iCloud and nobody
    /// else can read it.
    ///
    /// A preference rather than a promise: switching it off stops the sending,
    /// and the limit it was carrying is exactly as binding as it was before.
    var carriesBetweenDevices: Bool {
        didSet {
            guard carriesBetweenDevices != oldValue else { return }
            defaults.set(carriesBetweenDevices, forKey: Key.carriesBetweenDevices)
        }
    }

    /// Whether the morning note's permission prompt has already been put.
    ///
    /// Deliberately not "was it granted". That answer lives with iOS, it can
    /// change in Settings without this app running, and a second copy of it
    /// here would be a copy that goes stale. All this remembers is that the
    /// question has been asked, which is the only thing that must not happen
    /// twice.
    var hasAskedAboutRecap: Bool {
        didSet {
            guard hasAskedAboutRecap != oldValue else { return }
            defaults.set(hasAskedAboutRecap, forKey: Key.recapAsked)
        }
    }

    /// For a rehearsal, so that a machine can photograph either shape.
    nonisolated static func rehearse(row: RowShape, in defaults: UserDefaults = .standard) {
        defaults.set(row.rawValue, forKey: Key.row)
    }

    init(defaults: UserDefaults = .standard, hardware: Hardware = .current) {
        self.defaults = defaults
        self.row = defaults.string(forKey: Key.row)
            .flatMap(RowShape.init(rawValue:)) ?? .standard(on: hardware)
        self.rowMotion = defaults.string(forKey: Key.rowMotion)
            .flatMap(RowMotion.init(rawValue:)) ?? .leaves
        // `bool(forKey:)` answers false for a key nobody has written, which is
        // the wrong way round for a thing that is on unless it has been turned
        // off. Asked as an object first, so that "never chosen" and "chosen
        // false" are two different answers.
        self.saysWhatIsLeft = defaults.object(forKey: Key.saysWhatIsLeft) as? Bool ?? true
        // The same question, and the same reason for asking it as an object:
        // shown unless somebody has said otherwise, and `bool(forKey:)` cannot
        // tell "never asked" from "asked and answered no".
        self.showsSuggestions = defaults.object(forKey: Key.showsSuggestions) as? Bool ?? true
        self.carriesBetweenDevices = defaults.bool(forKey: Key.carriesBetweenDevices)
        self.hasAskedAboutRecap = defaults.bool(forKey: Key.recapAsked)
        self.appointment = Appointment(
            isOn: defaults.bool(forKey: Key.appointmentIsOn),
            // `integer(forKey:)` answers zero for a key nobody has written,
            // and midnight is a legitimate hour to choose, so the two have to
            // be told apart. Asked as an object first.
            minutesAfterMidnight: defaults.object(forKey: Key.appointmentAt) as? Int
                ?? Appointment.standard.minutesAfterMidnight
        )
        self.recap = Recap(
            // Asked as an object, because this is the one preference that is on
            // unless it has been turned off, and `bool(forKey:)` answers false
            // for a key nobody has written — which is the wrong way round.
            isOn: defaults.object(forKey: Key.recapIsOn) as? Bool ?? Recap.standard.isOn,
            // Asked as an object first, for the same reason the appointment is:
            // zero is a legitimate hour and also what an unwritten key answers.
            minutesAfterMidnight: defaults.object(forKey: Key.recapAt) as? Int
                ?? Recap.standard.minutesAfterMidnight
        )
    }
}
