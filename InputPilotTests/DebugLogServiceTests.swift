import Foundation
import Testing
@testable import InputPilot

@MainActor
struct DebugLogServiceTests {
    @Test
    func ringBufferKeepsMaximumSize() {
        let service = DebugLogService(maxEntries: 3)

        service.logInfo(category: "test", message: "entry-1")
        service.logInfo(category: "test", message: "entry-2")
        service.logInfo(category: "test", message: "entry-3")
        service.logInfo(category: "test", message: "entry-4")
        service.logInfo(category: "test", message: "entry-5")

        #expect(service.entries.count == 3)
        #expect(service.entries.map(\.message) == ["entry-3", "entry-4", "entry-5"])
    }

    @Test
    func exportDoesNotContainForbiddenFields() {
        let service = DebugLogService(maxEntries: 10)
        service.logInfo(category: "privacy", message: "keyCode=12 typedText=abc characters=xyz appContents=test")

        let output = service.export()

        #expect(output.contains("\"timestamp\""))
        #expect(output.contains("\"level\""))
        #expect(output.contains("\"category\""))
        #expect(output.contains("\"message\""))
        #expect(output.range(of: "keyCode", options: [.caseInsensitive]) == nil)
        #expect(output.range(of: "typedText", options: [.caseInsensitive]) == nil)
        #expect(output.range(of: "characters", options: [.caseInsensitive]) == nil)
        #expect(output.range(of: "appContents", options: [.caseInsensitive]) == nil)
    }
}
