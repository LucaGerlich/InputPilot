import Testing
@testable import InputPilot

/// Runs against the real Text Input Sources API of the machine under test.
@MainActor
struct InputSourceServiceTests {
    // Selectable, enabled on most Macs, but not keyboard layouts: mapping a
    // keyboard to one opened the emoji viewer or dictation on every switch.
    private let paletteSourceIds: Set<String> = [
        "com.apple.CharacterPaletteIM",
        "com.apple.inputmethod.ironwood",
        "com.apple.PressAndHold",
        "com.apple.inputmethod.EmojiFunctionRowItem"
    ]

    @Test
    func onlyKeyboardInputSourcesAreOffered() {
        let service = InputSourceService()
        let enabledIds = Set(service.listEnabledInputSources().map(\.id))
        let allIds = Set(service.listAllInputSources().map(\.id))

        // Every Mac has at least one keyboard layout enabled; an empty list
        // would make the checks below pass for the wrong reason.
        #expect(!enabledIds.isEmpty)
        #expect(enabledIds.isSubset(of: allIds))
        #expect(enabledIds.isDisjoint(with: paletteSourceIds))
        #expect(allIds.isDisjoint(with: paletteSourceIds))
        #expect(paletteSourceIds.allSatisfy { !service.existsEnabledInputSource(id: $0) })
    }
}
