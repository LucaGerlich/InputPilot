import Foundation
import IOKit.hid
import Testing
@testable import InputPilot

/// What the menu and Settings show, in the words a user reads.
@MainActor
struct AppStateDisplayTests {
    private let us = "com.apple.keylayout.US"
    private let german = "com.apple.keylayout.German"
    private let keyboard = ActiveKeyboardDevice(
        vendorId: 1452,
        productId: 832,
        productName: "Apple Keyboard",
        transport: "USB",
        locationId: 100
    )

    @Test
    func menuOffersToMapTheActiveKeyboardToTheCurrentSource() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (appState, monitor, _) = makeAppState(defaults: defaults)

        monitor.emit(keyboard)
        await waitFor { appState.activeKeyboardTitle != nil }

        #expect(appState.activeKeyboardTitle == "Apple Keyboard")
        #expect(appState.activeKeyboardTargetName == nil)
        #expect(appState.canUseCurrentSourceForActiveDevice)

        appState.useCurrentInputSourceForActiveDevice()

        #expect(appState.mappedInputSourceId(for: KeyboardDeviceKey(device: keyboard)) == german)
        #expect(appState.activeKeyboardTargetName == "German")
        #expect(!appState.canUseCurrentSourceForActiveDevice)
    }

    @Test
    func deviceDetailsUsePlainWordsAndShowALocationOnlyToTellTwinsApart() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (appState, monitor, _) = makeAppState(defaults: defaults)
        let twin = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 200
        )

        monitor.emit(keyboard)
        await waitFor { appState.knownDeviceKeys.count == 1 }
        #expect(appState.deviceSubtitle(for: KeyboardDeviceKey(device: keyboard)) == "USB · Vendor 1452 · Product 832")

        monitor.connected = [keyboard, twin]
        monitor.emit(twin)
        await waitFor { appState.knownDeviceKeys.count == 2 }
        #expect(appState.deviceSubtitle(for: KeyboardDeviceKey(device: twin)) == "USB · Vendor 1452 · Product 832 · Location 200")
    }

    @Test
    func statusLinesAvoidJargon() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (appState, _, _) = makeAppState(defaults: defaults, access: kIOHIDAccessTypeUnknown)

        #expect(appState.permissionLine == "Input Monitoring: not granted yet")
        #expect(appState.monitorLine == "Keyboard detection: stopped")
        #expect(MappingConflict.Reason.missingOrDisabled.explanation == "The input source was removed or disabled.")
    }

    // MARK: - Helpers

    private func makeAppState(
        defaults: UserDefaults,
        access: IOHIDAccessType = kIOHIDAccessTypeGranted
    ) -> (AppState, MockHIDKeyboardMonitor, MockInputSourceService) {
        let monitor = MockHIDKeyboardMonitor()
        let sources = MockInputSourceService()
        sources.enabledSources = [
            InputSourceInfo(id: us, name: "U.S.", isSelectable: true),
            InputSourceInfo(id: german, name: "German", isSelectable: true)
        ]
        sources.currentInputSourceIdValue = german

        let appState = AppState(
            permissionService: MockPermissionService(accessType: access),
            hidKeyboardMonitor: monitor,
            inputSourceService: sources,
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )
        return (appState, monitor, sources)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AppStateDisplayTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw DisplayTestError.failedToCreateUserDefaultsSuite
        }

        return (defaults, suiteName)
    }

    private func waitFor(
        maxAttempts: Int = 300,
        condition: @escaping () -> Bool
    ) async {
        for _ in 0..<maxAttempts {
            if condition() {
                return
            }

            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

private enum DisplayTestError: Error {
    case failedToCreateUserDefaultsSuite
}
