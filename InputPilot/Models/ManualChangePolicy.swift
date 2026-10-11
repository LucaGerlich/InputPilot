import Foundation

/// What InputPilot does when the input source is changed by something other
/// than itself - the user pressing ⌃Space, picking a layout from the menu bar,
/// Undo, or an input method switching modes.
enum ManualChangePolicy: String, CaseIterable, Identifiable {
    case keepUntilKeyboardChange
    case keepUntilSwitchBack
    case revertOnNextKeyPress
    case turnOffAutoSwitch

    static let `default` = ManualChangePolicy.keepUntilKeyboardChange

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .keepUntilKeyboardChange:
            return "Keep it until I switch keyboards"
        case .keepUntilSwitchBack:
            return "Keep it until I switch back myself"
        case .revertOnNextKeyPress:
            return "Switch back on the next key press"
        case .turnOffAutoSwitch:
            return "Turn off automatic switching"
        }
    }
}
