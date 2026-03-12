import SwiftUI

@main
struct InputPilotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("InputPilot", systemImage: "keyboard") {
            MenuBarMenuView()
                .environmentObject(appState)
        }

        Window("Debug Log", id: "debug-log") {
            DebugLogView()
                .environmentObject(appState)
        }
        .defaultSize(width: 600, height: 500)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .defaultSize(width: 600, height: 600)
        .keyboardShortcut(",", modifiers: .command)
    }
}
