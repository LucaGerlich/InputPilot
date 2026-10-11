import SwiftUI

/// First-run explainer. A menu bar app has no window of its own, so without
/// this a new user sees nothing happen at all: macOS never prompts for Input
/// Monitoring on its own, and the app stays invisible and inert. It stays until
/// its last step is done, so the relaunch macOS needs does not end in silence.
struct WelcomeView: View {
	@EnvironmentObject private var appState: AppState
	@EnvironmentObject private var loginItem: LoginItemController
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openWindow) private var openWindow
	/// Pre-checked: a menu bar utility that is not a login item silently stops
	/// working after every restart.
	@State private var openAtLogin = true

	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "keyboard")
				.font(.system(size: 48))
				.foregroundStyle(.tint)
				.accessibilityHidden(true)

			VStack(spacing: 8) {
				Text("Welcome to InputPilot")
					.font(.title2.weight(.semibold))

				Text("InputPilot switches your input language automatically, based on which keyboard you are typing on.")
					.multilineTextAlignment(.center)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			VStack(alignment: .leading, spacing: 10) {
				Label {
					Text("macOS needs to grant **Input Monitoring** before InputPilot can tell your keyboards apart.")
				} icon: {
					Image(systemName: "lock.shield")
				}
				.fixedSize(horizontal: false, vertical: true)

				Label {
					Text("InputPilot only uses key presses to tell **which keyboard** you are typing on — it never records what you type. Nothing you type leaves your Mac; the only network traffic is a daily update check and any update you choose to install.")
				} icon: {
					Image(systemName: "hand.raised")
				}
				.fixedSize(horizontal: false, vertical: true)
			}
			.font(.callout)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(14)
			.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

			actions
				// Without a width cap the stack takes its widest child's ideal
				// single-line width, and the window frame clips captions instead of
				// letting them wrap.
				.frame(maxWidth: .infinity)
		}
		.padding(28)
		.frame(width: 420)
		.onDisappear {
			// Closing the window once everything works counts as done, so it does
			// not come back at every launch.
			if !appState.needsPermissionOnboarding && !appState.needsRelaunchAfterGrant {
				appState.completeOnboarding()
			}
		}
	}

	@ViewBuilder
	private var actions: some View {
		if appState.status.permissionStatus == .denied {
			deniedActions
		} else if appState.needsPermissionOnboarding {
			grantActions
		} else if appState.needsRelaunchAfterGrant {
			relaunchActions
		} else {
			finalActions
		}
	}

	private var grantActions: some View {
		VStack(spacing: 10) {
			Button("Grant Access…") {
				appState.requestInputMonitoringPermission()
			}
			.keyboardShortcut(.defaultAction)
			.controlSize(.large)

			Button("Open System Settings") {
				appState.openInputMonitoringSettings()
			}
			.buttonStyle(.link)

			caption("If macOS does not show a prompt, add InputPilot under Privacy & Security → Input Monitoring with the + button.")
		}
	}

	/// macOS prompts only once. After a denial, "Grant Access" does nothing and
	/// InputPilot is already listed, just switched off.
	private var deniedActions: some View {
		VStack(spacing: 10) {
			Button("Open System Settings") {
				appState.openInputMonitoringSettings()
			}
			.keyboardShortcut(.defaultAction)
			.controlSize(.large)

			caption("Input Monitoring is switched off for InputPilot. Switch it on under Privacy & Security → Input Monitoring, then come back here.")
		}
	}

	private var relaunchActions: some View {
		VStack(spacing: 10) {
			Label("Permission granted.", systemImage: "checkmark.circle.fill")
				.foregroundStyle(.green)

			caption("macOS applies Input Monitoring when InputPilot starts again.")

			Button("Relaunch InputPilot") {
				appState.relaunch()
			}
			.keyboardShortcut(.defaultAction)
			.controlSize(.large)
		}
	}

	private var finalActions: some View {
		VStack(spacing: 12) {
			Label("You're all set.", systemImage: "checkmark.circle.fill")
				.foregroundStyle(.green)

			caption("Type a few keys on each keyboard you use, then give each one an input source in Settings.")

			Toggle("Open InputPilot at login", isOn: $openAtLogin)

			if let error = loginItem.lastError {
				Text(error)
					.font(.caption)
					.foregroundStyle(.red)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}

			HStack {
				Button("Open Settings…") {
					finish(openingSettings: true)
				}

				Button("Done") {
					finish(openingSettings: false)
				}
				.keyboardShortcut(.defaultAction)
			}
			.controlSize(.large)
		}
	}

	private func caption(_ text: String) -> some View {
		Text(text)
			.font(.caption)
			.foregroundStyle(.secondary)
			.multilineTextAlignment(.center)
			.fixedSize(horizontal: false, vertical: true)
	}

	private func finish(openingSettings: Bool) {
		loginItem.setEnabled(openAtLogin)
		// Stay open and show what went wrong rather than drop the choice silently.
		guard loginItem.lastError == nil else {
			return
		}

		appState.completeOnboarding()
		if openingSettings {
			openWindow(id: "settings")
			NSApp.activate(ignoringOtherApps: true)
		}
		dismiss()
	}
}
