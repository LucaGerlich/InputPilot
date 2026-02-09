import Foundation
import Carbon
import Testing
@testable import InputPilot

struct AppBackupSnapshotTests {
    @Test
    func jsonRoundtripPreservesCoreData() throws {
        let fingerprint = KeyboardFingerprint(
            vendorId: 1452,
            productId: 832,
            transport: "USB",
            isBuiltIn: false,
            productName: "Apple Keyboard",
            locationId: nil
        )
        let deviceKey = KeyboardDeviceKey(
            fingerprint: fingerprint,
            locationIdHint: 123
        )
        let mappingEntry = MappingBackupEntry(
            profileId: Profile.defaultProfileId,
            deviceKey: deviceKey,
            inputSourceId: "com.apple.keylayout.US",
            perDeviceFallbackInputSourceId: "com.apple.keylayout.German"
        )
        let settings = AppBackupSettings(
            autoSwitchEnabled: true,
            pauseUntil: Date(timeIntervalSince1970: 2_000),
            showNotificationOnSwitch: true,
            hotkeyAssignments: [
                .toggleAutoSwitch: KeyCombo(
                    keyCode: 0,
                    modifiers: UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
                )
            ],
            syncViaICloudDriveEnabled: true
        )
        let snapshot = AppBackupSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_000),
            profiles: Profile.defaultProfiles,
            activeProfileId: Profile.defaultProfileId,
            mappingEntries: [mappingEntry],
            globalFallbackInputSourceId: "com.apple.keylayout.US",
            deviceFilterRule: DeviceFilterRule(
                mode: .denyList,
                fingerprints: [fingerprint]
            ),
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let decoded = try AppBackupMigrator.decodeSnapshot(from: data)

        #expect(decoded.schemaVersion == AppBackupSnapshot.currentSchemaVersion)
        #expect(decoded.profiles == snapshot.profiles)
        #expect(decoded.activeProfileId == snapshot.activeProfileId)
        #expect(decoded.mappingEntries == snapshot.mappingEntries)
        #expect(decoded.globalFallbackInputSourceId == snapshot.globalFallbackInputSourceId)
        #expect(decoded.deviceFilterRule == snapshot.deviceFilterRule)
        #expect(decoded.settings == snapshot.settings)
    }

    @Test
    func decodeWithMissingFieldsUsesDefaults() throws {
        let data = Data("""
        {
          "schemaVersion": 1
        }
        """.utf8)

        let decoded = try AppBackupMigrator.decodeSnapshot(from: data)

        #expect(decoded.profiles == Profile.defaultProfiles)
        #expect(decoded.activeProfileId == Profile.defaultProfileId)
        #expect(decoded.mappingEntries.isEmpty)
        #expect(decoded.deviceFilterRule == DeviceFilterRule())
        #expect(decoded.settings.autoSwitchEnabled == true)
        #expect(decoded.settings.showNotificationOnSwitch == false)
    }

    @Test
    func migrationPlaceholderRejectsUnsupportedSchemaVersion() {
        let data = Data("""
        {
          "schemaVersion": 99
        }
        """.utf8)

        do {
            _ = try AppBackupMigrator.decodeSnapshot(from: data)
            #expect(Bool(false), "Expected unsupported schema version to throw.")
        } catch let error as AppBackupError {
            #expect(error == .unsupportedSchemaVersion(99))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error.localizedDescription)")
        }
    }
}
