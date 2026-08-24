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

    /// For a rehearsal, so that a machine can photograph either shape.
    nonisolated static func rehearse(row: RowShape, in defaults: UserDefaults = .standard) {
        defaults.set(row.rawValue, forKey: Key.row)
    }

    init(defaults: UserDefaults = .standard, hardware: Hardware = .current) {
        self.defaults = defaults
        self.row = defaults.string(forKey: Key.row)
            .flatMap(RowShape.init(rawValue:)) ?? .standard(on: hardware)
    }
}
