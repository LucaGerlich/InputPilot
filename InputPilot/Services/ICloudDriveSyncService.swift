import Foundation

final class ICloudDriveSyncService: ICloudDriveSyncServicing {
    private let fileManager: FileManager
    private let backupFileName: String

    init(
        fileManager: FileManager = .default,
        backupFileName: String = "InputPilot-Backup.json"
    ) {
        self.fileManager = fileManager
        self.backupFileName = backupFileName
    }

    var isAvailable: Bool {
        backupFileURL != nil
    }

    func loadBackupData() throws -> Data? {
        guard let backupFileURL else {
            return nil
        }

        guard fileManager.fileExists(atPath: backupFileURL.path) else {
            return nil
        }

        return try Data(contentsOf: backupFileURL)
    }

    func saveBackupData(_ data: Data) throws {
        guard let backupFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let parentURL = backupFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try data.write(to: backupFileURL, options: [.atomic])
    }

    private var backupFileURL: URL? {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }

        return containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("InputPilot", isDirectory: true)
            .appendingPathComponent(backupFileName, isDirectory: false)
    }
}

final class NoOpICloudDriveSyncService: ICloudDriveSyncServicing {
    var isAvailable: Bool {
        false
    }

    func loadBackupData() throws -> Data? {
        nil
    }

    func saveBackupData(_ data: Data) throws {
        _ = data
    }
}
