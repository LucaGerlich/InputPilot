import Foundation
import Carbon

final class GlobalHotkeyService: GlobalHotkeyServicing {
    private static let signature: OSType = 0x49504F54 // "IPOT"
    private static let eventHandlerUPP: EventHandlerUPP = { _, eventRef, userData in
        guard let userData else {
            return OSStatus(eventNotHandledErr)
        }

        let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
        return service.handleHotkeyEvent(eventRef)
    }

    private var eventHandlerRef: EventHandlerRef?
    private var handler: ((HotkeyAction) -> Void)?
    private var hotKeyRefsByAction: [HotkeyAction: EventHotKeyRef] = [:]
    private var actionsByIdentifier: [UInt32: HotkeyAction] = [:]

    init() {
        _ = installEventHandlerIfNeeded()
    }

    deinit {
        unregisterAll()
        uninstallEventHandler()
    }

    func setHandler(_ handler: @escaping (HotkeyAction) -> Void) {
        self.handler = handler
        _ = installEventHandlerIfNeeded()
    }

    func register(shortcuts: [HotkeyAction: KeyCombo]) -> [HotkeyAction: String] {
        unregisterAll()

        guard installEventHandlerIfNeeded() else {
            return Dictionary(
                uniqueKeysWithValues: shortcuts.keys.map { action in
                    (action, "Could not install global hotkey event handler.")
                }
            )
        }

        var errors: [HotkeyAction: String] = [:]
        for action in HotkeyAction.allCases {
            guard let combo = shortcuts[action] else {
                continue
            }

            var hotKeyRef: EventHotKeyRef?
            var hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: action.registrationIdentifier
            )
            let status = RegisterEventHotKey(
                combo.keyCode,
                combo.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let hotKeyRef {
                hotKeyRefsByAction[action] = hotKeyRef
                actionsByIdentifier[action.registrationIdentifier] = action
            } else {
                errors[action] = "OSStatus \(status)"
            }
        }

        return errors
    }

    func unregisterAll() {
        for hotKeyRef in hotKeyRefsByAction.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefsByAction.removeAll()
        actionsByIdentifier.removeAll()
    }

    private func installEventHandlerIfNeeded() -> Bool {
        if eventHandlerRef != nil {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerUPP,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        return status == noErr
    }

    private func uninstallEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func handleHotkeyEvent(_ eventRef: EventRef?) -> OSStatus {
        guard let eventRef else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard hotKeyID.signature == Self.signature,
              let action = actionsByIdentifier[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }

        handler?(action)
        return noErr
    }
}

final class NoOpGlobalHotkeyService: GlobalHotkeyServicing {
    func setHandler(_ handler: @escaping (HotkeyAction) -> Void) {
        _ = handler
    }

    func register(shortcuts: [HotkeyAction: KeyCombo]) -> [HotkeyAction: String] {
        _ = shortcuts
        return [:]
    }

    func unregisterAll() {}
}
