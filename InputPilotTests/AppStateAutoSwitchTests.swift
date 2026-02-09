import Foundation
import IOKit.hid
import Testing
@testable import InputPilot

@MainActor
struct AppStateAutoSwitchTests {
    @Test
    func autoSwitchesWhenActiveDeviceChangesAndMappingExists() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
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

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])
        #expect(appState.activeKeyboardDevice == device)
        #expect(appState.lastAction?.fromInputSourceId == "com.apple.keylayout.German")
        #expect(appState.lastAction?.toInputSourceId == "com.apple.keylayout.US")
        #expect(appState.previousInputSourceIdBeforeLastSwitch == "com.apple.keylayout.German")
    }

    @Test
    func undoSelectsPreviousInputSource() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(device)
        await waitFor {
            inputSourceService.selectCalls.count == 1
        }

        appState.undoLastSwitch()

        #expect(inputSourceService.selectCalls == [
            "com.apple.keylayout.US",
            "com.apple.keylayout.German"
        ])
        #expect(appState.currentInputSourceId == "com.apple.keylayout.German")
        #expect(appState.lastAction == nil)
        #expect(appState.previousInputSourceIdBeforeLastSwitch == nil)
    }

    @Test
    func doesNotAutoSwitchWhenPaused() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        appState.pause(minutes: 15)
        keyboardMonitor.emit(device)
        await waitFor {
            appState.activeKeyboardDevice != nil
        }

        #expect(appState.isAutoSwitchActive == false)
        #expect(inputSourceService.selectCalls.isEmpty)
    }

    @Test
    func resumeReEnablesAutoSwitch() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        appState.pause(minutes: 15)
        appState.resume()
        keyboardMonitor.emit(device)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(appState.isAutoSwitchActive == true)
        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])
    }

    @Test
    func doesNotAutoSwitchWithoutMapping() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(device)
        await waitFor {
            appState.activeKeyboardDevice != nil
        }

        #expect(inputSourceService.selectCalls.isEmpty)
    }

    @Test
    func invalidMappingUsesPerDeviceFallback() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.Missing")
        mappingStore.setPerDeviceFallback(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
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

        #expect(appState.activeKeyboardDevice == device)
        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])
    }

    @Test
    func invalidFallbackLeadsToNoSwitch() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.Missing")
        mappingStore.setPerDeviceFallback(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.AlsoMissing")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )
        appState.setGlobalFallbackInputSourceId("com.apple.keylayout.Unknown")

        keyboardMonitor.emit(device)
        await waitFor {
            appState.activeKeyboardDevice != nil
        }

        #expect(inputSourceService.selectCalls.isEmpty)
    }

    @Test
    func temporaryOverrideHasPrecedenceOverMappingAndFallback() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)
        let overrideSourceId = "com.apple.keylayout.French"

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true),
            InputSourceInfo(id: overrideSourceId, name: "French", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")
        mappingStore.setPerDeviceFallback(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.German")

        let temporaryOverrideStore = MockTemporaryOverrideStore()
        temporaryOverrideStore.setOverride(
            deviceFingerprintKey: deviceKey.primaryIdentifier,
            inputSourceId: overrideSourceId,
            expiresAt: nil,
            persistAcrossLaunch: false
        )

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            temporaryOverrideStore: temporaryOverrideStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(device)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(appState.activeKeyboardDevice == device)
        #expect(inputSourceService.selectCalls == [overrideSourceId])
    }

    @Test
    func expiredTemporaryOverrideFallsBackToMapping() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let clock = ImmediateClock()
        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.French", name: "French", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let temporaryOverrideStore = MockTemporaryOverrideStore()
        temporaryOverrideStore.setOverride(
            deviceFingerprintKey: deviceKey.primaryIdentifier,
            inputSourceId: "com.apple.keylayout.French",
            expiresAt: clock.now.addingTimeInterval(1),
            persistAcrossLaunch: true
        )

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            temporaryOverrideStore: temporaryOverrideStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: clock
        )

        keyboardMonitor.emit(device)
        await waitFor {
            inputSourceService.selectCalls.count == 1
        }
        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.French"])

        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"
        appState.refreshInputSourcesNow()
        clock.advance(by: .seconds(2))

        keyboardMonitor.emit(device)
        await waitFor {
            inputSourceService.selectCalls.count == 2
        }

        #expect(inputSourceService.selectCalls == [
            "com.apple.keylayout.French",
            "com.apple.keylayout.US"
        ])
        #expect(temporaryOverrideStore.temporaryOverride(for: deviceKey.primaryIdentifier, now: clock.now) == nil)
    }

    @Test
    func detectsConflictsOnLaunchAndRefresh() throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let conflictedDevice = KeyboardDeviceKey(vendorId: 1452, productId: 832, transport: "USB", locationId: 123)
        let mappedSource = "com.apple.keylayout.German"

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true)
        ]
        inputSourceService.allSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: mappedSource, name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.US"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: conflictedDevice, inputSourceId: mappedSource)

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        #expect(appState.mappingConflicts.count == 1)
        #expect(appState.mappingConflicts.first?.deviceKey == conflictedDevice)
        #expect(appState.mappingConflicts.first?.mappedSourceId == mappedSource)

        inputSourceService.enabledSources.append(
            InputSourceInfo(id: mappedSource, name: "German", isSelectable: true)
        )
        appState.refreshInputSourcesNow()

        #expect(appState.mappingConflicts.isEmpty)
    }

    @Test
    func autoSwitchUsesPrimaryFingerprintWhenLocationChanges() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storedDeviceKey = KeyboardDeviceKey(
            vendorId: 1452,
            productId: 832,
            transport: "USB",
            locationId: 100
        )
        let movedDevice = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 900
        )

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.German"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: storedDeviceKey, inputSourceId: "com.apple.keylayout.US")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(movedDevice)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.US"])
        #expect(appState.knownDeviceKeys.count == 1)
        #expect(appState.knownDeviceKeys.first == storedDeviceKey)
    }

    @Test
    func autoSwitchUsesLocationTieBreakerForDuplicatePrimaryFingerprints() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstDeviceKey = KeyboardDeviceKey(
            vendorId: 5000,
            productId: 77,
            transport: "USB",
            locationId: 1,
            productName: "CloneBoard"
        )
        let secondDeviceKey = KeyboardDeviceKey(
            vendorId: 5000,
            productId: 77,
            transport: "USB",
            locationId: 2,
            productName: "CloneBoard"
        )
        let secondDevice = ActiveKeyboardDevice(
            vendorId: 5000,
            productId: 77,
            productName: "CloneBoard",
            transport: "USB",
            locationId: 2
        )

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.US"

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: firstDeviceKey, inputSourceId: "com.apple.keylayout.US")
        mappingStore.setMapping(deviceKey: secondDeviceKey, inputSourceId: "com.apple.keylayout.German")

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )

        keyboardMonitor.emit(secondDevice)
        await waitFor {
            !inputSourceService.selectCalls.isEmpty
        }

        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.German"])
        #expect(appState.activeKeyboardDevice == secondDevice)
    }

    @Test
    func switchingProfileChangesEffectiveMapping() async throws {
        let suiteName = "AppStateAutoSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppStateTestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let profileManager = ProfileManager(
            defaults: defaults,
            profilesStorageKey: "profiles.switching",
            activeProfileStorageKey: "profiles.switching.active"
        )
        let mappingStore = MappingStore(
            defaults: defaults,
            profileManager: profileManager,
            storageKey: "mappings.switching",
            migrationVersionKey: "mappings.switching.migration"
        )
        let clock = ImmediateClock()

        let device = ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 832,
            productName: "Apple Keyboard",
            transport: "USB",
            locationId: 123
        )
        let deviceKey = KeyboardDeviceKey(device: device)

        profileManager.setActiveProfile(id: Profile.defaultProfileId)
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        profileManager.setActiveProfile(id: Profile.codingProfileId)
        mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.German")

        let permissionService = MockPermissionService(accessType: kIOHIDAccessTypeGranted)
        let keyboardMonitor = MockHIDKeyboardMonitor()
        let inputSourceService = MockInputSourceService()
        inputSourceService.enabledSources = [
            InputSourceInfo(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true),
            InputSourceInfo(id: "com.apple.keylayout.German", name: "German", isSelectable: true)
        ]
        inputSourceService.currentInputSourceIdValue = "com.apple.keylayout.US"

        let appState = AppState(
            permissionService: permissionService,
            hidKeyboardMonitor: keyboardMonitor,
            inputSourceService: inputSourceService,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: clock,
            profileManager: profileManager
        )

        keyboardMonitor.emit(device)
        await waitFor {
            inputSourceService.selectCalls.count == 1
        }
        #expect(inputSourceService.selectCalls == ["com.apple.keylayout.German"])
        #expect(appState.activeProfileId == Profile.codingProfileId)

        clock.advance(by: .seconds(2))
        appState.setActiveProfile(Profile.defaultProfileId)

        await waitFor {
            inputSourceService.selectCalls.count == 2
        }
        #expect(inputSourceService.selectCalls == [
            "com.apple.keylayout.German",
            "com.apple.keylayout.US"
        ])
        #expect(appState.activeProfileId == Profile.defaultProfileId)
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

private enum AppStateTestError: Error {
    case failedToCreateUserDefaultsSuite
}
