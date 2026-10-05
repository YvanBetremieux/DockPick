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

    /// Fenêtres affichables de l'app, dans l'ordre AX (de la plus récente à la plus ancienne).
    func windows(for app: NSRunningApplication) -> [AppWindow] {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.15)
        let onScreen = Self.onScreenWindowIDs(pid: pid)

        let candidates = appElement.elements(kAXWindowsAttribute).enumerated().map { index, element in
            let windowID = element.windowID
            let minimized = element.bool(kAXMinimizedAttribute) ?? false
            let origin = element.point(kAXPositionAttribute) ?? .zero
            let size = element.size(kAXSizeAttribute) ?? .zero
            let info = WindowInfo(
                id: windowID.map { Int($0) } ?? -(index + 1),
                windowID: windowID,
                title: element.string(kAXTitleAttribute) ?? "",
                subrole: element.string(kAXSubroleAttribute),
                isMinimized: minimized,
                isOnCurrentSpace: windowID.map { onScreen.contains($0) } ?? true,
                frame: CGRect(origin: origin, size: size)
            )
            return AppWindow(info: info, element: element)
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
