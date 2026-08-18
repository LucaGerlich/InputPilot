import SwiftUI

@main
struct InputPilotApp: App {
    @StateObject private var appState = AppState()
    private let updaterService = UpdaterService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView(updaterService: updaterService)
                .environmentObject(appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appState)
        }

        Window("Welcome to InputPilot", id: "welcome") {
            WelcomeView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

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

/// The menu bar icon doubles as the app's only launch-time view, so it is the
/// one place that can open the first-run window without an AppKit delegate.
private struct MenuBarLabel: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "keyboard")
            .onAppear {
                guard appState.needsPermissionOnboarding else {
                    return
                }

                openWindow(id: "welcome")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}
