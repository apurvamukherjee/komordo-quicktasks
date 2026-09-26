/// Namespace for values shared by the app, the backup manifest and the MCP helper.
public enum KomodoCore {
    /// Written to `manifest.json`; a restore refuses a backup with a newer value (ARCHITECTURE §7).
    public static let schemaVersion = 1
}
