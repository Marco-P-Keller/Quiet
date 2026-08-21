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
}

/// The handful of things that are about how Quiet looks rather than what it
/// promises.
///
/// Deliberately not kept where the limit is. The limit lives in the keychain
/// because it has to outlive the app being deleted — that is the whole promise,
/// and the About screen says so in as many words. A preference about the shape
/// of a row surviving a delete-and-reinstall would be a surprise rather than a
/// feature, so it lives in the ordinary place preferences live.
@MainActor
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let rowKey = "quiet.row.shape"

    /// Instagram's bar to begin with, because a first launch should look like
    /// the thing it is showing rather than like an opinion about it.
    var row: RowShape {
        didSet {
            guard row != oldValue else { return }
            defaults.set(row.rawValue, forKey: Self.rowKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.row = defaults.string(forKey: Self.rowKey)
            .flatMap(RowShape.init(rawValue:)) ?? .bar
    }
}
