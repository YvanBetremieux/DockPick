import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }
}

@MainActor
final class OverlayController {
    var onChoose: ((AppWindow, NSRunningApplication, NSScreen) -> Void)?

    private(set) var currentPID: pid_t?
    private var panel: OverlayPanel?
    private var model: PickerModel?
    private var windows: [AppWindow] = []
    private var app: NSRunningApplication?
    private var screen: NSScreen?
    private var thumbnailTask: Task<Void, Never>?
    private var resignObserver: NSObjectProtocol?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(app: NSRunningApplication, windows: [AppWindow], on screen: NSScreen, thumbnails: ThumbnailProvider?) {
        hide()
        let appName = app.localizedName ?? "App"
        let items = windows.enumerated().map { index, window in
            PickerItem(
                id: window.info.id,
                title: WindowFilter.displayTitle(for: window.info, appName: appName, index: index),
                isMinimized: window.info.isMinimized
            )
        }
        let model = PickerModel(items: items, appIcon: app.icon)
        model.onChoose = { [weak self] index in self?.choose(index) }
        model.onCancel = { [weak self] in self?.hide() }

        let panel = OverlayPanel(contentRect: screen.visibleFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Juste sous le Dock : le Dock reste cliquable au-dessus de la vue.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        let host = NSHostingView(rootView: PickerView(model: model))
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)
        panel.contentView = effect
        host.frame = effect.bounds
        panel.setFrame(screen.visibleFrame, display: true)
        panel.makeKeyAndOrderFront(nil)

        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }

        self.panel = panel
        self.model = model
        self.windows = windows
        self.app = app
        self.screen = screen
        self.currentPID = app.processIdentifier

        if let thumbnails {
            let ids = windows.compactMap(\.info.windowID)
            let maxSize = CGSize(width: screen.visibleFrame.width / 2, height: screen.visibleFrame.height / 2)
            thumbnailTask = Task { [weak model] in
                let images = await thumbnails.thumbnails(for: ids, maxSize: maxSize)
                guard !Task.isCancelled else { return }
                model?.setThumbnails(Dictionary(uniqueKeysWithValues: images.map { (Int($0.key), $0.value) }))
            }
        }
    }

    func hide() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil
        windows = []
        app = nil
        screen = nil
        currentPID = nil
    }

    private func choose(_ index: Int) {
        guard windows.indices.contains(index), let app, let screen else { return }
        let window = windows[index]
        hide()
        onChoose?(window, app, screen)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let model else { return false }
        switch event.keyCode {
        case 53: hide()                       // Échap
        case 36, 76: model.chooseSelected()   // Entrée, Entrée du pavé
        case 123: model.move(.left)
        case 124: model.move(.right)
        case 125: model.move(.down)
        case 126: model.move(.up)
        default:
            guard let character = event.charactersIgnoringModifiers?.first,
                  let digit = character.wholeNumberValue, (1...9).contains(digit)
            else { return false }
            model.choose(digit - 1)
        }
        return true
    }
}
