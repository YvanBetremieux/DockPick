import Foundation
import Sparkle

@MainActor
final class UpdaterController: ObservableObject {
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { objectWillChange.send(); controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloads: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { objectWillChange.send(); controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    var canCheck: Bool { controller.updater.canCheckForUpdates }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
