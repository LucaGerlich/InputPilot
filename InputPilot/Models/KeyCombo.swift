import Foundation
import Carbon

struct KeyCombo: Codable, Hashable, Identifiable {
    let keyCode: UInt32
    let modifiers: UInt32

    var id: String {
        "\(keyCode)-\(modifiers)"
    }

    var carbonModifiers: UInt32 {
        modifiers
    }

    var displayName: String {
        let modifierParts = modifierDisplayParts
        let keyPart = Self.keyName(for: keyCode)

        guard !modifierParts.isEmpty else {
            return keyPart
        }

        return "\(modifierParts.joined(separator: "+"))+\(keyPart)"
    }

    static var predefinedCombos: [KeyCombo] {
        [
            .commandOptionControlA,
            .commandOptionControlS,
            .commandOptionControlD,
            .commandOptionControlF,
            .commandOptionControlM
        ]
    }

    static func predefinedCombo(withId id: String) -> KeyCombo? {
        predefinedCombos.first(where: { $0.id == id })
    }

    private var modifierDisplayParts: [String] {
        var parts: [String] = []

        if (modifiers & Self.commandModifierMask) != 0 {
            parts.append("Cmd")
        }
        if (modifiers & Self.optionModifierMask) != 0 {
            parts.append("Opt")
        }
        if (modifiers & Self.controlModifierMask) != 0 {
            parts.append("Ctrl")
        }
        if (modifiers & Self.shiftModifierMask) != 0 {
            parts.append("Shift")
        }

        return parts
    }

    private static let commandModifierMask = UInt32(cmdKey)
    private static let optionModifierMask = UInt32(optionKey)
    private static let controlModifierMask = UInt32(controlKey)
    private static let shiftModifierMask = UInt32(shiftKey)
    private static let commandOptionControlModifiers: UInt32 =
        commandModifierMask | optionModifierMask | controlModifierMask

    private static let commandOptionControlA = KeyCombo(
        keyCode: 0,
        modifiers: commandOptionControlModifiers
    )
    private static let commandOptionControlS = KeyCombo(
        keyCode: 1,
        modifiers: commandOptionControlModifiers
    )
    private static let commandOptionControlD = KeyCombo(
        keyCode: 2,
        modifiers: commandOptionControlModifiers
    )
    private static let commandOptionControlF = KeyCombo(
        keyCode: 3,
        modifiers: commandOptionControlModifiers
    )
    private static let commandOptionControlM = KeyCombo(
        keyCode: 46,
        modifiers: commandOptionControlModifiers
    )

    private static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 31: "O"
        case 32: "U"
        case 34: "I"
        case 35: "P"
        case 37: "L"
        case 38: "J"
        case 40: "K"
        case 45: "N"
        case 46: "M"
        default: "KeyCode \(keyCode)"
        }
    }
}
