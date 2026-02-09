import Foundation
import Carbon
import Testing
@testable import InputPilot

struct KeyComboTests {
    @Test
    func keyComboCodableRoundtrip() throws {
        let original = KeyCombo(
            keyCode: 46,
            modifiers: UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)

        #expect(decoded == original)
    }
}
