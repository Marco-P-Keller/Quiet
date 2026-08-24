import Foundation

/// What Quiet is running on, reduced to the two facts that change a default.
///
/// The row along the bottom is the one thing in the app that is purely a
/// matter of taste, and both answers are right on the right hardware. The
/// island is a shape that belongs to a phone with a cutout in the glass and to
/// a system that draws in that idiom; on an older phone, or an older system, it
/// is an opinion arriving uninvited. So the shape the app opens with is asked
/// of the device rather than decided once for everybody.
///
/// A value rather than a lookup, so that the rule below can be tested against
/// every phone Apple has shipped without any of them being in the room.
struct Hardware: Sendable, Equatable {
    /// The model identifier, as the kernel gives it: `iPhone16,1` and friends.
    /// On a simulator this is the phone being simulated, not the Mac doing it.
    var model: String

    /// The major number of the system version — 26 for iOS 26.1.
    var systemMajorVersion: Int

    /// The phone and system this copy of Quiet is actually on.
    static var current: Hardware {
        Hardware(
            model: currentModel,
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    /// An iPhone 15 or newer.
    ///
    /// The model numbers do not line up with the names, and the one place they
    /// cross is exactly here: `iPhone15,2` and `iPhone15,3` are the iPhone 14
    /// Pro and Pro Max, while `iPhone15,4` and `iPhone15,5` are the iPhone 15
    /// and 15 Plus. The 15 Pro pair then starts a new number again at
    /// `iPhone16,1`. So generation 15 is split at the comma, and everything
    /// above it is simply newer.
    ///
    /// Anything that is not an iPhone — a simulator identifier nobody
    /// recognises, an iPad, a future name in a shape this does not know — is
    /// not newer. It gets the bar, which is the answer that is never wrong.
    var isIPhone15OrNewer: Bool {
        guard let (generation, variant) = Self.generation(of: model) else { return false }
        if generation > 15 { return true }
        return generation == 15 && variant >= 4
    }

    /// The two numbers in `iPhone15,4`, and nothing else.
    static func generation(of model: String) -> (generation: Int, variant: Int)? {
        guard model.hasPrefix("iPhone") else { return nil }
        let numbers = model.dropFirst("iPhone".count).split(separator: ",")
        guard numbers.count == 2,
              let generation = Int(numbers[0]),
              let variant = Int(numbers[1]) else { return nil }
        return (generation, variant)
    }

    /// A simulator reports the Mac it is running on, and names the phone it is
    /// pretending to be in the environment instead. Asking there first is what
    /// makes the rule visible on a machine that has no iPhone 15 in it.
    private static var currentModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        guard uname(&system) == 0 else { return "" }
        return withUnsafeBytes(of: &system.machine) { raw in
            let bytes = raw.prefix(while: { $0 != 0 })
            return String(decoding: bytes, as: UTF8.self)
        }
    }
}
