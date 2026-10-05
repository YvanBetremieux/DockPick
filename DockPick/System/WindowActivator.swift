import AppKit
import ApplicationServices

@MainActor
enum WindowActivator {
    static func activate(_ window: AppWindow, app: NSRunningApplication, mode: OpenMode, screen: NSScreen) {
        let element = window.element
        if element.bool(kAXMinimizedAttribute) == true {
            element.setBool(kAXMinimizedAttribute, false)
        }

        // Activation coopérative (macOS 14+) : on passe par AX, l'appel AppKit sert de filet de sécurité.
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        appElement.setBool(kAXFrontmostAttribute, true)
        let raised = element.perform(kAXRaiseAction)
        element.setBool(kAXMainAttribute, true)
        app.activate(options: [])

        guard raised else {
            AppDelegate.log.info("Fenêtre introuvable, activation de l'app seule")
            return
        }

        switch mode {
        case .focus:
            break
        case .maximize:
            guard element.bool("AXFullScreen") != true else { break }
            let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            let target = ScreenGeometry.axRect(fromCocoa: screen.visibleFrame, primaryScreenHeight: primaryHeight)
            // Position, puis taille, puis position : certaines apps rognent la taille à l'écran d'origine.
            element.setPoint(kAXPositionAttribute, target.origin)
            element.setSize(kAXSizeAttribute, target.size)
            element.setPoint(kAXPositionAttribute, target.origin)
        case .fullScreen:
            element.setBool("AXFullScreen", true)
        }
    }
}
