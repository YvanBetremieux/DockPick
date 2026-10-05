import AppKit
import ScreenCaptureKit

final class ThumbnailProvider {
    /// Captures ponctuelles ; renvoie un dictionnaire vide sans autorisation d'enregistrement d'écran.
    func thumbnails(for windowIDs: [CGWindowID], maxSize: CGSize) async -> [CGWindowID: NSImage] {
        guard !windowIDs.isEmpty, CGPreflightScreenCaptureAccess() else { return [:] }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else {
            return [:]
        }
        let byID = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })

        return await withTaskGroup(of: (CGWindowID, NSImage?).self) { group in
            for id in windowIDs {
                guard let window = byID[id] else { continue }
                group.addTask { (id, await Self.capture(window, maxSize: maxSize)) }
            }
            var result: [CGWindowID: NSImage] = [:]
            for await (id, image) in group {
                if let image { result[id] = image }
            }
            return result
        }
    }

    private static func capture(_ window: SCWindow, maxSize: CGSize) async -> NSImage? {
        guard window.frame.width > 0, window.frame.height > 0 else { return nil }
        let scale = min(1, maxSize.width / window.frame.width, maxSize.height / window.frame.height)
        let pointSize = CGSize(width: window.frame.width * scale, height: window.frame.height * scale)

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(pointSize.width * 2))
        configuration.height = max(1, Int(pointSize.height * 2))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true

        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) else {
            return nil
        }
        return NSImage(cgImage: image, size: pointSize)
    }
}
