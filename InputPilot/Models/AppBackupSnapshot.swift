import Foundation

enum AppBackupError: Error, LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "Unsupported backup schema version: \(version)."
        case .invalidPayload:
            return "Backup payload is invalid."
        }
    }
}

struct AppBackupSettings: Codable, Equatable {
    var autoSwitchEnabled: Bool
    var pauseUntil: Date?
    var showNotificationOnSwitch: Bool
    var hotkeyAssignments: [HotkeyAction: KeyCombo]
    var syncViaICloudDriveEnabled: Bool

    init(
        autoSwitchEnabled: Bool = true,
        pauseUntil: Date? = nil,
        showNotificationOnSwitch: Bool = false,
        hotkeyAssignments: [HotkeyAction: KeyCombo] = [:],
        syncViaICloudDriveEnabled: Bool = false
    ) {
        self.autoSwitchEnabled = autoSwitchEnabled
        self.pauseUntil = pauseUntil
        self.showNotificationOnSwitch = showNotificationOnSwitch
        self.hotkeyAssignments = hotkeyAssignments
        self.syncViaICloudDriveEnabled = syncViaICloudDriveEnabled
    }
}

struct AppBackupSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var profiles: [Profile]
    var activeProfileId: String
    var mappingEntries: [MappingBackupEntry]
    var globalFallbackInputSourceId: String?
    var deviceFilterRule: DeviceFilterRule
    var settings: AppBackupSettings

    init(
        exportedAt: Date,
        profiles: [Profile],
        activeProfileId: String,
        mappingEntries: [MappingBackupEntry],
        globalFallbackInputSourceId: String?,
        deviceFilterRule: DeviceFilterRule,
        settings: AppBackupSettings
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.profiles = profiles
        self.activeProfileId = activeProfileId
        self.mappingEntries = mappingEntries
        self.globalFallbackInputSourceId = globalFallbackInputSourceId
        self.deviceFilterRule = deviceFilterRule
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case profiles
        case activeProfileId
        case mappingEntries
        case globalFallbackInputSourceId
        case deviceFilterRule
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date(timeIntervalSince1970: 0)
        profiles = try container.decodeIfPresent([Profile].self, forKey: .profiles) ?? Profile.defaultProfiles
        activeProfileId = try container.decodeIfPresent(String.self, forKey: .activeProfileId)
            ?? Profile.defaultProfileId
        mappingEntries = try container.decodeIfPresent([MappingBackupEntry].self, forKey: .mappingEntries) ?? []
        globalFallbackInputSourceId = try container.decodeIfPresent(String.self, forKey: .globalFallbackInputSourceId)
        deviceFilterRule = try container.decodeIfPresent(DeviceFilterRule.self, forKey: .deviceFilterRule)
            ?? DeviceFilterRule()
        settings = try container.decodeIfPresent(AppBackupSettings.self, forKey: .settings)
            ?? AppBackupSettings()
    }
}

enum AppBackupMigrator {
    static func decodeSnapshot(from data: Data) throws -> AppBackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(AppBackupSnapshot.self, from: data)
        guard snapshot.schemaVersion == AppBackupSnapshot.currentSchemaVersion else {
            throw AppBackupError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }

        return snapshot
    }
}
