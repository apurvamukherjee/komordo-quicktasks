extension KeychainSecret {
    /// The password for protected backups. It lives in the Keychain, never the database, so exports carry no
    /// secret (FEATURES §4.21) and the daily backup can seal itself without asking. Debug builds take
    /// `-backupPassword`.
    static let backupPassword = KeychainSecret(
        service: "app.komodo.backup", account: "backup-password", debugOverride: "backupPassword")
}
