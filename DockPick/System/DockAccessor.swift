import AppKit
import ApplicationServices

/// Accès AX au processus Dock : pid et position de la barre d'icônes.
@MainActor
final class DockAccessor {
    static let bundleID = "com.apple.dock"

    private var cachedApp: NSRunningApplication?
    private var cachedElement: AXUIElement?

    var pid: pid_t? { dockApp()?.processIdentifier }

    /// Cadre de la barre d'icônes en coordonnées AX, ou nil si le Dock est introuvable.
    func iconStripFrame() -> CGRect? {
        guard let element = dockElement() else { return nil }
        guard let list = element.elements(kAXChildrenAttribute).first(where: { $0.string(kAXRoleAttribute) == kAXListRole as String }),
              let origin = list.point(kAXPositionAttribute),
              let size = list.size(kAXSizeAttribute)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func dockApp() -> NSRunningApplication? {
        if let cachedApp, !cachedApp.isTerminated { return cachedApp }
        cachedApp = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first
        cachedElement = nil
        return cachedApp
    }

    private func dockElement() -> AXUIElement? {
        guard let app = dockApp() else { return nil }
        if let cachedElement { return cachedElement }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.1)
        cachedElement = element
        return element
    }
}
