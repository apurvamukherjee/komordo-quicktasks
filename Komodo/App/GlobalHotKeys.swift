import Carbon.HIToolbox
import KomodoCore
import OSLog

/// ⌘⇧B, ⌘⇧T and ⌘⇧P from any app (FEATURES §4.17) through Carbon's `RegisterEventHotKey`, which needs no
/// Accessibility permission and no dependency (HANDOFF §6). A shortcut another app registered first is reported
/// back so Settings can say so.
@MainActor final class GlobalHotKeys {
    var onPress: (GlobalShortcut) -> Void = { _ in }

    private var registered: [GlobalShortcut: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?

    /// 'Kmdo', so our hot key events are told apart from any other code's.
    private static let signature: OSType = 0x4B6D_646F

    func install() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &id)
                let index = Int(id.id)
                // Carbon delivers hot key events on the main thread.
                MainActor.assumeIsolated {
                    let hotKeys = Unmanaged<GlobalHotKeys>.fromOpaque(context).takeUnretainedValue()
                    guard GlobalShortcut.allCases.indices.contains(index) else { return }
                    hotKeys.onPress(GlobalShortcut.allCases[index])
                }
                return noErr
            }, 1, &spec, context, &handler)
        if status != noErr {
            Logger(subsystem: "app.komodo.Komodo", category: "hotkeys").error("Handler failed: \(status)")
        }
    }

    /// Replaces every registration with the settings' shortcuts; returns the ones another app already holds.
    func register(_ settings: AppSettings) -> Set<GlobalShortcut> {
        for ref in registered.values { UnregisterEventHotKey(ref) }
        registered = [:]
        var conflicts: Set<GlobalShortcut> = []
        for (index, action) in GlobalShortcut.allCases.enumerated() {
            let combo = settings.shortcut(for: action)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                combo.keyCode, Self.carbonModifiers(combo.modifiers),
                EventHotKeyID(signature: Self.signature, id: UInt32(index)), GetApplicationEventTarget(), 0, &ref)
            if status == eventHotKeyExistsErr {
                conflicts.insert(action)
            } else if let ref, status == noErr {
                registered[action] = ref
            } else {
                Logger(subsystem: "app.komodo.Komodo", category: "hotkeys").error("\(combo.label) failed: \(status)")
            }
        }
        return conflicts
    }

    private static func carbonModifiers(_ modifiers: KeyCombo.Modifiers) -> UInt32 {
        var result = 0
        if modifiers.contains(.command) { result |= cmdKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.control) { result |= controlKey }
        return UInt32(result)
    }
}
