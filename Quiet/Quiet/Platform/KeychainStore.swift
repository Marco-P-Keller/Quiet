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

    /// Cleared the first time the keychain turns a write down. Nothing sets it
    /// back: one refusal is enough to know the app's memory cannot be trusted.
    private(set) var isWritable = true

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
        guard let data = try? encoder.encode(Boxed(value: value)) else { return }

        let identity = identity(of: key)
        let update = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else {
            note(update, doing: "update")
            return
        }

        var insert = identity
        insert[kSecValueData as String] = data
        // Readable once the phone has been unlocked after a restart, so a
        // background write cannot fail. Never synced to iCloud: this is about
        // this device, and it is nobody else's business.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        note(SecItemAdd(insert as CFDictionary, nil), doing: "add")
    }

    func remove(_ key: StoreKey) {
        let status = SecItemDelete(identity(of: key) as CFDictionary)
        if status != errSecItemNotFound {
            note(status, doing: "delete")
        }
    }

    /// Records a refusal instead of dropping it on the floor.
    ///
    /// The old version of this file ignored every status code these calls
    /// return. A keychain that quietly declines — an unsigned build, a device
    /// still locked after a restart, a full store — would have left the app
    /// starting from nothing every launch, looking perfectly healthy while
    /// doing the one thing it promises never to do.
    private func note(_ status: OSStatus, doing action: String) {
        guard status != errSecSuccess else { return }
        isWritable = false
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        NSLog("Quiet: keychain %@ failed with %d (%@)", action, status, message)
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
