import Foundation
import Security

/// Quiet's memory.
///
/// The keychain, not `UserDefaults`, and the choice is the whole point: keychain
/// items outlive the app that wrote them. Delete Quiet, install it again, and
/// your limit and your weekly cooldown are still there, exactly as you left
/// them. A limit you can clear by holding down an icon and tapping Delete is not
/// a limit.
///
/// This is said plainly during setup. Nobody should discover it by accident.
final class KeychainStore: StateStore, HighWaterMarkStore {
    private let service: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Which values the keychain has refused and not since accepted.
    ///
    /// A refusal used to be permanent — one turned-down write and the app said
    /// its memory could not be trusted for the rest of the launch. That is the
    /// right answer for a keychain that is genuinely broken and the wrong one
    /// for the failure that actually happens: a device still locked after a
    /// restart refuses everything, and then accepts everything the moment
    /// somebody types their passcode. The old rule left a red banner standing
    /// over a perfectly healthy store until the app was killed.
    ///
    /// So the question is asked per value rather than once for the app. A key
    /// enters this set when a write for it is refused and leaves it when a
    /// later write for the same key succeeds — which is exactly the condition
    /// under which the thing that was lost has been written down again.
    private var unwritten: Set<StoreKey> = []

    /// True while every value Quiet has tried to write is actually written
    /// down. False the moment one is not, and true again once it is.
    var isWritable: Bool { unwritten.isEmpty }

    init(service: String = "app.quiet.state") {
        self.service = service
    }

    func load<T: Codable>(_ type: T.Type, for key: StoreKey) -> T? {
        var query = identity(of: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? decoder.decode(Boxed<T>.self, from: data).value
    }

    func save<T: Codable>(_ value: T, for key: StoreKey) {
        guard let data = try? encoder.encode(Boxed(value: value)) else {
            // The last silent path in this file. Encoding cannot realistically
            // fail for the four small values Quiet stores, but "realistically"
            // is exactly the word that let the keychain failures through.
            //
            // This one does not heal. A value that cannot be turned into bytes
            // will not be turned into bytes by asking again.
            unwritten.insert(key)
            NSLog("Quiet: could not encode %@ for the keychain", key.rawValue)
            return
        }

        let identity = identity(of: key)
        let update = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if update == errSecSuccess {
            note(errSecSuccess, doing: "update", of: key)
            return
        }
        guard update == errSecItemNotFound else {
            note(update, doing: "update", of: key)
            return
        }

        var insert = identity
        insert[kSecValueData as String] = data
        // Readable once the phone has been unlocked after a restart, so a
        // background write cannot fail. Never synced to iCloud: this is about
        // this device, and it is nobody else's business.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        note(SecItemAdd(insert as CFDictionary, nil), doing: "add", of: key)
    }

    func remove(_ key: StoreKey) {
        let status = SecItemDelete(identity(of: key) as CFDictionary)
        if status != errSecItemNotFound {
            note(status, doing: "delete", of: key)
        }
    }

    /// Records what the keychain said, in both directions.
    ///
    /// The first version of this file ignored every status code these calls
    /// return. A keychain that quietly declines — an unsigned build, a device
    /// still locked after a restart, a full store — would have left the app
    /// starting from nothing every launch, looking perfectly healthy while
    /// doing the one thing it promises never to do.
    ///
    /// The second recorded refusals and nothing else, which was half a step:
    /// it could say a value had been lost and could never say it had come
    /// back. A success is as much a fact as a failure, and it is the one that
    /// takes the banner down.
    private func note(_ status: OSStatus, doing action: String, of key: StoreKey) {
        guard status != errSecSuccess else {
            unwritten.remove(key)
            return
        }
        unwritten.insert(key)
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        NSLog("Quiet: keychain %@ of %@ failed with %d (%@)",
              action, key.rawValue, status, message)
    }

    var highWaterMark: Date? {
        get { storedHighWaterMark }
        set { storedHighWaterMark = newValue }
    }

    /// The attributes that name one item. Accessibility is deliberately absent:
    /// it belongs on the item when it is created, not in the query used to find
    /// it again.
    private func identity(of key: StoreKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
