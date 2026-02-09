import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DebugLogView: View {
    @EnvironmentObject private var appState: AppState

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Copy to Clipboard") {
                    appState.copyDebugLogToClipboard()
                }

                Button("Export…") {
                    exportDebugLog()
                }

                Spacer()

                Text("\(appState.debugLogEntries.count) entries")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(Array(appState.debugLogEntries.reversed())) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(entry.level.rawValue.uppercased())
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(levelColor(entry.level))

                            Text(entry.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(Self.timestampFormatter.string(from: entry.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.message)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 460)
    }

    private func levelColor(_ level: DebugLogLevel) -> Color {
        switch level {
        case .info:
            return .blue
        case .warn:
            return .orange
        case .error:
            return .red
        }
    }

    private func exportDebugLog() {
        let panel = NSSavePanel()
        panel.title = "Export Debug Log"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = "InputPilot-Debug-\(Self.filenameFormatter.string(from: Date())).txt"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        appState.exportDebugLog(to: url)
    }
}
