import Foundation

enum HotkeyAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case toggleAutoSwitch
    case useCurrentInputSourceForActiveDevice

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .toggleAutoSwitch:
            return "Toggle Auto-Switch"
        case .useCurrentInputSourceForActiveDevice:
            return "Use current input source for this device"
        }
    }

    var defaultsStorageKey: String {
        switch self {
        case .toggleAutoSwitch:
            return "hotkey.toggleAutoSwitch"
        case .useCurrentInputSourceForActiveDevice:
            return "hotkey.useCurrentInputSourceForActiveDevice"
        }
    }

    var registrationIdentifier: UInt32 {
        switch self {
        case .toggleAutoSwitch:
            return 1
        case .useCurrentInputSourceForActiveDevice:
            return 2
        }
    }

    var defaultKeyCombo: KeyCombo {
        switch self {
        case .toggleAutoSwitch:
            return KeyCombo.predefinedCombos[0]
        case .useCurrentInputSourceForActiveDevice:
            return KeyCombo.predefinedCombos[4]
        }
    }
}
