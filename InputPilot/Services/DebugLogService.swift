import Foundation

enum DebugLogLevel: String, Codable {
    case info
    case warn
    case error
}

struct LogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: DebugLogLevel
    let category: String
    let message: String
}

final class DebugLogService: DebugLogServicing {
    private static let forbiddenTokens = [
        "keycode",
        "typedtext",
        "characters",
        "appcontents",
        "keystroke"
    ]

    private let maxEntries: Int
    private var buffer: [LogEntry] = []

    init(maxEntries: Int = 200) {
        self.maxEntries = max(1, maxEntries)
    }

    var entries: [LogEntry] {
        buffer
    }

    func logInfo(category: String, message: String) {
        append(level: .info, category: category, message: message)
    }

    func logWarn(category: String, message: String) {
        append(level: .warn, category: category, message: message)
    }

    func logError(category: String, message: String) {
        append(level: .error, category: category, message: message)
    }

    func export() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(buffer),
           let output = String(data: data, encoding: .utf8) {
            return output
        }

        let formatter = ISO8601DateFormatter()
        return buffer.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        }
        .joined(separator: "\n")
    }

    private func append(level: DebugLogLevel, category: String, message: String) {
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: sanitize(category),
            message: sanitize(message)
        )

        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    private func sanitize(_ value: String) -> String {
        var sanitized = value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        for token in Self.forbiddenTokens {
            sanitized = sanitized.replacingOccurrences(
                of: token,
                with: "[redacted]",
                options: [.caseInsensitive]
            )
        }
        return sanitized
    }
}
