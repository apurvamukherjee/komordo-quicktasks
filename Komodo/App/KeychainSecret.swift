import Foundation
import Security

/// One generic password in the Keychain, readable after the first unlock and never synced, as ARCHITECTURE §6
/// keeps every secret: out of the database and every export.
struct KeychainSecret {
    var service: String
    var account: String
    /// Debug builds read this launch argument instead, so scratch runs and captures never touch the Keychain.
    var debugOverride: String

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private var overridden: String? {
        #if DEBUG
            UserDefaults.standard.string(forKey: debugOverride)
        #else
            nil
        #endif
    }

    func read() throws(KeychainError) -> String? {
        if let overridden { return overridden }
        var result: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return String(decoding: data, as: UTF8.self)
    }

    func save(_ secret: String) throws(KeychainError) {
        guard overridden == nil else { return }
        try remove()
        var item = query
        item[kSecValueData as String] = Data(secret.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func remove() throws(KeychainError) {
        guard overridden == nil else { return }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

/// The Keychain refused a read or write.
struct KeychainError: Error, Equatable {
    var status: OSStatus
}
