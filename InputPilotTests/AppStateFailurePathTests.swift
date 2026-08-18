import Foundation
import IOKit.hid
import Testing
@testable import InputPilot

@MainActor
struct AppStateFailurePathTests {
    @Test
    func deniedPermissionAtLaunchSurfacesWarningAndDoesNotStartMonitor() throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeDenied)
        let keyboardMonitor = MockHIDKeyboardMonitor()

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: MockInputSourceService(),
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        #expect(!keyboardMonitor.isRunning)
        #expect(appState.status.permissionStatus == .denied)
        #expect(appState.permissionWarningMessage != nil)
        #expect(appState.activeKeyboardDevice == nil)
        #expect(appState.status.activeKeyboard == "none")
    }

    @Test
    func permissionRevocationMidSessionClearsActiveDevice() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock(),
            permissionPollInterval: .milliseconds(20)
        )

        keyboardMonitor.emit(device)
        await waitFor {
            appState.activeKeyboardDevice != nil
        }

        permissionService.accessType = kIOHIDAccessTypeDenied
        await waitFor {
            appState.activeKeyboardDevice == nil
        }

        #expect(!keyboardMonitor.isRunning)
        #expect(appState.status.permissionStatus == .denied)
        #expect(appState.activeKeyboardDevice == nil)
        #expect(appState.status.activeKeyboard == "none")
    }

    @Test
    func hidStartFailureSurfacesErrorWhenPermissionGranted() throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let keyboardMonitor = MockHIDKeyboardMonitor()
        keyboardMonitor.startResult = false
        keyboardMonitor.lastStartErrorMessage = "No matching keyboard HID device available."

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: MockInputSourceService(),
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        #expect(!keyboardMonitor.isRunning)
        #expect(appState.lastAutoSwitchError == "No matching keyboard HID device available.")
        #expect(appState.keyboardMonitorHint != nil)
    }

    @Test
    func selectInputSourceFailureRecordsErrorWithoutArmingCooldown() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"
        inputSourceService.selectInputSourceResult = false

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(device)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(appState.lastAutoSwitchError != nil)
        #expect(appState.lastAction == nil)
        #expect(appState.previousInputSourceIdBeforeLastSwitch == nil)
        #expect(appState.canUndoLastSwitch == false)

        // A failed switch must not arm the cooldown: the very next event retries.
        inputSourceService.selectInputSourceResult = true
        keyboardMonitor.emit(device)
        await waitFor {
            inputSourceService.selectCalls.count >= 2
        }

        #expect(inputSourceService.selectCalls.last == "com.apple.keylayout.US")
        #expect(appState.lastAction?.toInputSourceId == "com.apple.keylayout.US")
    }

    @Test
    func modifierOnlyKeyDoesNotTriggerSwitchByDefault() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(device, kind: .keyDown(isModifier: true))
        await waitFor {
            appState.activeKeyboardDevice != nil
        }

        // Device display updates, but no switch happens for a lone modifier press.
        #expect(appState.activeKeyboardDevice == device)
        #expect(inputSourceService.selectCalls.isEmpty)

        // A real keypress afterwards still switches.
        keyboardMonitor.emit(device, kind: .keyDown(isModifier: false))
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])
    }

    @Test
    func modifierOnlyKeyTriggersSwitchWhenOptedIn() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )
        appState.setSwitchOnModifierOnlyKeys(true)

        keyboardMonitor.emit(device, kind: .keyDown(isModifier: true))
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])
        #expect(appState.switchOnModifierOnlyKeys)
    }

    @Test
    func externallyChangedInputSourceDoesNotSuppressSwitch() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let clock = ImmediateClock()
        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: clock
        )

        keyboardMonitor.emit(device)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }
        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])

        // The user switches to German outside the app; AppState's cached value
        // still says US. A keypress must still switch back using a fresh read.
        clock.advance(by: .seconds(2))
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        keyboardMonitor.emit(device)
        await waitFor {
            inputSourceService.selectCalls.count >= 2
        }

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US", "com.apple.keylayout.US"])
        #expect(appState.previousInputSourceIdBeforeLastSwitch == "com.apple.keylayout.German")
    }

    @Test
    func remapWhileDeviceActiveTriggersExactlyOneSwitch() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let clock = ImmediateClock()
        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: clock
        )

        keyboardMonitor.emit(device)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }
        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])

        clock.advance(by: .seconds(2))
        appState.setMapping(for: deviceKey, inputSourceId: "com.apple.keylayout.German")
        await waitFor {
            inputSourceService.selectCalls.count >= 2
        }

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US", "com.apple.keylayout.German"])

        // Re-applying the same mapping while already on that source is a no-op.
        clock.advance(by: .seconds(2))
        appState.setMapping(for: deviceKey, inputSourceId: "com.apple.keylayout.German")
        await waitFor(maxAttempts: 20) {
            inputSourceService.selectCalls.count >= 3
        }
        #expect(inputSourceService.selectCalls.count == 2)
    }

    @Test
    func deviceRemovalClearsActiveDevice() async throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = usbKeyboard()
        let deviceKey = KeyboardDeviceKey(device: device)

        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = defaultSources()
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(device)
        await waitFor {
            appState.activeKeyboardDevice != nil
        }

        keyboardMonitor.emitRemoval(device)
        await waitFor {
            appState.activeKeyboardDevice == nil
        }

        #expect(appState.activeKeyboardDevice == nil)
        #expect(appState.status.activeKeyboard == "none")
        // Mappings must survive an unplug.
        #expect(mappingStore.getMapping(for: deviceKey) == "com.apple.keylayout.US")
    }

    @Test
    func onboardingIsRequestedWhenPermissionIsMissing() throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeDenied),
            hidKeyboardMonitor: MockHIDKeyboardMonitor(),
            inputSourceService: MockInputSourceService(),
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        #expect(appState.needsPermissionOnboarding)
        #expect(!appState.needsRelaunchAfterGrant)
    }

    @Test
    func onboardingIsNotRequestedOnceMonitoringRuns() throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: MockHIDKeyboardMonitor(),
            inputSourceService: MockInputSourceService(),
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        #expect(!appState.needsPermissionOnboarding)
        #expect(!appState.needsRelaunchAfterGrant)
    }

    @Test
    func relaunchIsRequestedWhenGrantedButMonitorCannotStart() throws {
        let suiteName = "AppStateFailurePathTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FailurePathTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        // The state macOS leaves an app in right after the user grants access:
        // permission reads as granted, but HID still refuses until relaunch.
        let keyboardMonitor = MockHIDKeyboardMonitor()
        keyboardMonitor.startResult = false
        keyboardMonitor.lastStartErrorMessage = "HID monitor start blocked by macOS permissions/sandbox (kIOReturnNotPermitted)."

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: MockInputSourceService(),
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        #expect(!appState.needsPermissionOnboarding)
        #expect(appState.needsRelaunchAfterGrant)
    }

    private func usbKeyboard() -> ActiveKeyboardDevice {
        ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
    }

    private func defaultSources() -> [InputSourceInfo] {
        [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
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

private enum FailurePathTestError: Error {
    case failedToCreateUserDefaultsSuite
}
