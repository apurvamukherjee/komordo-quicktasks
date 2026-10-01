import Foundation
import Security

/// The password for protected backups. It lives in the Keychain, never the database, so exports carry no secret
/// (FEATURES §4.21) and the daily backup can seal itself without asking.
enum BackupPassword {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.komodo.backup",
            kSecAttrAccount as String: "backup-password",
        ]
    }

    static func read() throws(KeychainError) -> String? {
        #if DEBUG
            // `-backupPassword <pw>` stands in for the Keychain, so captures and scratch runs never touch it.
            if let password = UserDefaults.standard.string(forKey: "backupPassword") { return password }
        #endif
        var result: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ password: String) throws(KeychainError) {
        #if DEBUG
            if UserDefaults.standard.string(forKey: "backupPassword") != nil { return }
        #endif
        try remove()
        var item = query
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    static func remove() throws(KeychainError) {
        #if DEBUG
            if UserDefaults.standard.string(forKey: "backupPassword") != nil { return }
        #endif
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

/// The Keychain refused a read or write.
struct KeychainError: Error, Equatable {
    var status: OSStatus
}
