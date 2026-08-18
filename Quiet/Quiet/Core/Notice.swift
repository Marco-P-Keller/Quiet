import Foundation

/// One sentence the app needs to say, briefly.
///
/// There are exactly two occasions: a tap that was refused, and time running
/// out. Notices replace one another rather than stacking, and the token is what
/// tells a view that a new one has arrived even when the words are identical.
struct Notice: Equatable, Sendable {
    var text: String
    var token: Int
}
