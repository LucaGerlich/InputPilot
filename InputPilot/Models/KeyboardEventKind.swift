import Foundation

enum KeyboardEventKind: Equatable {
    case keyDown(isModifier: Bool)
    case deviceStabilized

    var isNonModifierKeyDown: Bool {
        if case .keyDown(let isModifier) = self {
            return !isModifier
        }

        return false
    }
}
