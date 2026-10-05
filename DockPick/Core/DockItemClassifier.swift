import Foundation

enum DockItemKind: Equatable {
    case application(URL)
    case other
}

enum DockItemClassifier {
    static func classify(role: String?, subrole: String?, url: URL?) -> DockItemKind {
        guard role == "AXDockItem",
              subrole == "AXApplicationDockItem",
              let url,
              url.pathExtension == "app"
        else { return .other }
        return .application(url.standardizedFileURL)
    }
}
