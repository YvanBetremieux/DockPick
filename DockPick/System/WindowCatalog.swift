import AppKit
import ApplicationServices

struct AppWindow {
    let info: WindowInfo
    let element: AXUIElement
}

@MainActor
final class WindowCatalog {
    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    /// Budget total d'interrogation AX : au-delà, on rend le clic au Dock plutôt que de figer la souris.
    static let budget: TimeInterval = 0.15

    /// Fenêtres affichables de l'app, dans l'ordre AX (de la plus récente à la plus ancienne),
    /// ou nil si l'app ne répond pas assez vite.
    func windows(for app: NSRunningApplication) -> [AppWindow]? {
        let start = ProcessInfo.processInfo.systemUptime
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.1)
        let elements = appElement.elements(kAXWindowsAttribute)
        let onScreen = Self.onScreenWindowIDs(pid: pid)
        let attributes = [kAXTitleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, kAXPositionAttribute, kAXSizeAttribute]

        var candidates: [AppWindow] = []
        for (index, element) in elements.enumerated() {
            guard ProcessInfo.processInfo.systemUptime - start < Self.budget else {
                AppDelegate.log.info("Fenêtres de \(app.bundleIdentifier ?? "?", privacy: .public) trop lentes à lister : clic rendu au Dock")
                return nil
            }
            AXUIElementSetMessagingTimeout(element, 0.1)
            let values = element.values(attributes)
            let windowID = element.windowID
            let minimized = values[2] as? Bool ?? false
            let info = WindowInfo(
                id: windowID.map { Int($0) } ?? -(index + 1),
                windowID: windowID,
                title: values[0] as? String ?? "",
                subrole: values[1] as? String,
                isMinimized: minimized,
                isOnCurrentSpace: windowID.map { onScreen.contains($0) } ?? true,
                frame: CGRect(origin: AXUIElement.decodePoint(values[3]) ?? .zero, size: AXUIElement.decodeSize(values[4]) ?? .zero)
            )
            candidates.append(AppWindow(info: info, element: element))
        }

        let options = WindowFilterOptions(includeMinimized: settings.includeMinimized, includeOtherSpaces: settings.includeOtherSpaces)
        let keptIDs = Set(WindowFilter.filter(candidates.map(\.info), options: options).map(\.id))
        return candidates.filter { keptIDs.contains($0.info.id) }
    }

    /// Fenêtres normales de l'app présentes sur le Space courant (même masquées par d'autres fenêtres).
    static func onScreenWindowIDs(pid: pid_t) -> Set<CGWindowID> {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return Set(list.compactMap { entry in
            guard (entry[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  let number = entry[kCGWindowNumber as String] as? CGWindowID
            else { return nil }
            return number
        })
    }
}
