import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater so UI code has one
/// obvious entry point and no direct framework dependency.
@MainActor
final class UpdaterService {
	private let updaterController = SPUStandardUpdaterController(
		startingUpdater: true,
		updaterDelegate: nil,
		userDriverDelegate: nil
	)

	func checkForUpdates() {
		updaterController.checkForUpdates(nil)
	}
}
