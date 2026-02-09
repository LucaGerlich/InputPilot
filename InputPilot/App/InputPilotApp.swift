import SwiftUI

@main
struct InputPilotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("InputPilot", systemImage: "keyboard") {
            MenuBarMenuView()
                .environmentObject(appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
