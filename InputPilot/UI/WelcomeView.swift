import SwiftUI

/// First-run explainer. A menu bar app has no window of its own, so without
/// this a new user sees nothing happen at all: macOS never prompts for Input
/// Monitoring on its own, and the app stays invisible and inert.
struct WelcomeView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "keyboard")
				.font(.system(size: 48))
				.foregroundStyle(.tint)

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
					Text("InputPilot only detects **which keyboard** sent a key press — never what you type. Nothing leaves your Mac.")
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
		}
		.padding(28)
		.frame(width: 420)
	}

	@ViewBuilder
	private var actions: some View {
		if appState.needsPermissionOnboarding {
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

				Text("If macOS does not show a prompt, add InputPilot manually under Privacy & Security → Input Monitoring.")
					.font(.caption)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}
			// Without a width cap the stack takes its widest child's ideal
			// single-line width, and the window frame clips the caption
			// instead of letting it wrap.
			.frame(maxWidth: .infinity)
		} else if appState.needsRelaunchAfterGrant {
			VStack(spacing: 10) {
				Label("Permission granted.", systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)

				Text("macOS applies Input Monitoring on the next launch. Quit and reopen InputPilot to finish setup.")
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)

				Button("Quit InputPilot") {
					NSApp.terminate(nil)
				}
				.keyboardShortcut(.defaultAction)
				.controlSize(.large)
			}
			.frame(maxWidth: .infinity)
		} else {
			VStack(spacing: 10) {
				Label("You're all set.", systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)

				Text("Press a key on each keyboard you want to configure, then open Settings from the menu bar to assign an input source.")
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)

				Button("Done") {
					dismiss()
				}
				.keyboardShortcut(.defaultAction)
				.controlSize(.large)
			}
			.frame(maxWidth: .infinity)
		}
	}
}
