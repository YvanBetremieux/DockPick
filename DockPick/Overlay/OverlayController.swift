import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }
}

/// Suit la souris même quand DockPick n'est pas l'app active (SwiftUI `onHover` ne le fait pas).
final class HoverTrackingEffectView: NSVisualEffectView {
    /// Point en coordonnées avec origine en haut à gauche, comme la grille SwiftUI.
    var onMouseMoved: ((CGPoint) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseMoved(with event: NSEvent) { report(event) }
    override func mouseEntered(with event: NSEvent) { report(event) }

    private func report(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseMoved?(CGPoint(x: point.x, y: bounds.height - point.y))
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

    /// `dockFrame` : barre d'icônes du Dock en coordonnées AX, que la vue doit éviter.
    func show(app: NSRunningApplication, windows: [AppWindow], on screen: NSScreen, dockFrame: CGRect?, thumbnails: ThumbnailProvider?) {
        hide()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let dockFrames = dockFrame.map { [ScreenGeometry.cocoaRect(fromAX: $0, primaryScreenHeight: primaryHeight)] } ?? []
        let frame = DockAvoidance.usableFrame(visibleFrame: screen.visibleFrame, dockFrames: dockFrames)
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

        let panel = OverlayPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Juste sous le Dock : le Dock reste cliquable au-dessus de la vue.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }

        let effect = HoverTrackingEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.onMouseMoved = { [weak model, weak effect] point in
            guard let model, let effect else { return }
            let frames = GridLayout.frames(count: model.items.count, in: CGRect(origin: .zero, size: effect.bounds.size))
            if let index = GridLayout.index(at: point, in: frames), model.selectedIndex != index {
                model.selectedIndex = index
            }
        }
        let host = NSHostingView(rootView: PickerView(model: model))
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)
        panel.contentView = effect
        host.frame = effect.bounds
        panel.setFrame(frame, display: true)
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
            let maxSize = CGSize(width: frame.width / 2, height: frame.height / 2)
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
        case KeyCodes.escape: hide()
        case KeyCodes.returnKey, KeyCodes.keypadEnter: model.chooseSelected()
        case KeyCodes.left: model.move(.left)
        case KeyCodes.right: model.move(.right)
        case KeyCodes.down: model.move(.down)
        case KeyCodes.up: model.move(.up)
        default:
            guard let digit = KeyCodes.digit(for: event.keyCode) else { return false }
            model.choose(digit - 1)
        }
        return true
    }
}
