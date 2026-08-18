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
        guard update == errSecItemNotFound else { return }

        var insert = identity
        insert[kSecValueData as String] = data
        // Readable once the phone has been unlocked after a restart, so a
        // background write cannot fail. Never synced to iCloud: this is about
        // this device, and it is nobody else's business.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(insert as CFDictionary, nil)
    }

    func remove(_ key: StoreKey) {
        _ = SecItemDelete(identity(of: key) as CFDictionary)
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
