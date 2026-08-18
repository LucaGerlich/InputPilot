import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater so UI code has one
/// obvious entry point and no direct framework dependency.
///
/// The updater starts on first use, not at app launch: automatic checks stay
/// disabled until the EdDSA key exists (see Config/AppInfo.plist), and
/// starting Sparkle with an unconfigured key aborts launch in headless test
/// hosts. Switch to startingUpdater: true once the key ships and scheduled
/// background checks are wanted.
@MainActor
final class UpdaterService {
	private let updaterController = SPUStandardUpdaterController(
		startingUpdater: false,
		updaterDelegate: nil,
		userDriverDelegate: nil
	)
	private var hasStartedUpdater = false

	func checkForUpdates() {
		if !hasStartedUpdater {
			updaterController.startUpdater()
			hasStartedUpdater = true
		}

		updaterController.checkForUpdates(nil)
	}
}
