import CoreGraphics
import Foundation

struct WindowInfo: Equatable, Identifiable {
    var id: Int
    var windowID: CGWindowID?
    var title: String
    var subrole: String?
    var isMinimized: Bool
    var isOnCurrentSpace: Bool
    /// Coordonnées AX : origine en haut à gauche de l'écran principal.
    var frame: CGRect
}

struct WindowFilterOptions {
    var includeMinimized: Bool
    var includeOtherSpaces: Bool
}

enum WindowFilter {
    static let minimumSide: CGFloat = 50

    static func filter(_ windows: [WindowInfo], options: WindowFilterOptions) -> [WindowInfo] {
        windows.filter { window in
            guard window.subrole == "AXStandardWindow" else { return false }
            guard window.frame.width >= minimumSide, window.frame.height >= minimumSide else { return false }
            if window.isMinimized { return options.includeMinimized }
            if !window.isOnCurrentSpace { return options.includeOtherSpaces }
            return true
        }
    }

    static func displayTitle(for window: WindowInfo, appName: String, index: Int) -> String {
        let title = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "\(appName) — fenêtre \(index + 1)" : title
    }
}
