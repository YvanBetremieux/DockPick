import AppKit
import ServiceManagement

@MainActor
enum Uninstaller {
    static func confirmAndUninstall() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Désinstaller DockPick ?"
        alert.informativeText = "DockPick sera retiré du démarrage, ses réglages et autorisations seront supprimés, et l'application sera placée dans la Corbeille."
        alert.addButton(withTitle: "Désinstaller")
        alert.addButton(withTitle: "Annuler")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        uninstall()
    }

    private static func uninstall() {
        try? SMAppService.mainApp.unregister()

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            for service in ["Accessibility", "ScreenCapture"] {
                run("/usr/bin/tccutil", ["reset", service, bundleID])
            }
            if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: caches.appendingPathComponent(bundleID))
            }
        }

        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            DispatchQueue.main.async {
                if let error { NSAlert(error: error).runModal() }
                NSApp.terminate(nil)
            }
        }
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}
