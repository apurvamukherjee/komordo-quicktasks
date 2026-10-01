import FoundationModels

/// Settings ▸ AI's Apple Intelligence line (DESIGN_SYSTEM §13.23): whether the on-device model can be used.
enum AppleIntelligence {
    enum Status: Equatable {
        case available
        case turnedOff
        case unsupportedMac
        case needsNewerMacOS
    }

    static var status: Status {
        guard #available(macOS 26, *) else { return .needsNewerMacOS }
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
        // Still downloading counts as on its way rather than off.
        case .unavailable(.modelNotReady): return .available
        case .unavailable: return .unsupportedMac
        }
    }
}
