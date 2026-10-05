import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let log = Logger(subsystem: "io.github.yvanbetremieux.DockPick", category: "app")

    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private let settings = Settings.shared
    private let permissions = PermissionsManager()
    private lazy var catalog = WindowCatalog(settings: settings)
    private let overlay = OverlayController()
    private let thumbnails = ThumbnailProvider()
    private var updater: UpdaterController?
    private var monitor: DockClickMonitor?
    private var menuBar: MenuBarController?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        let updater = UpdaterController()
        self.updater = updater

        overlay.onChoose = { [weak self] window, app, screen in
            guard let self else { return }
            WindowActivator.activate(window, app: app, mode: self.settings.openMode, screen: screen)
        }

        menuBar = MenuBarController(
            settings: settings,
            permissions: permissions,
            actions: .init(
                openSettings: { [weak self] in self?.showSettings() },
                checkForUpdates: { updater.checkForUpdates() },
                requestAccessibility: { [weak self] in self?.showOnboarding() }
            )
        )

        if permissions.accessibilityGranted {
            accessibilityReady()
        } else {
            showOnboarding()
            permissions.whenAccessibilityGranted { [weak self] in self?.accessibilityReady() }
        }
    }

    private func accessibilityReady() {
        menuBar?.refreshIcon()
        guard monitor == nil else { return }
        let monitor = DockClickMonitor { [weak self] app, location in
            self?.handleDockClick(app: app, axLocation: location) ?? false
        }
        if monitor.start() {
            self.monitor = monitor
            Self.log.info("Surveillance du Dock démarrée")
        } else {
            Self.log.error("Impossible de créer l'event tap")
        }
    }

    private func handleDockClick(app: NSRunningApplication, axLocation: CGPoint) -> Bool {
        let excluded = settings.isExcluded(app.bundleIdentifier)
        let pickerForThisApp = overlay.isVisible && overlay.currentPID == app.processIdentifier
        let eligible = settings.enabled && !excluded && !pickerForThisApp
        let windows = eligible ? catalog.windows(for: app) : []
        let decision = ClickPolicy.decide(ClickContext(
            enabled: settings.enabled,
            isExcluded: excluded,
            windowCount: windows.count,
            pickerVisibleForThisApp: pickerForThisApp
        ))
        Self.log.debug("Clic Dock \(app.bundleIdentifier ?? "?", privacy: .public) : \(windows.count) fenêtres → \(String(describing: decision), privacy: .public)")

        switch decision {
        case .passThrough:
            if overlay.isVisible { overlay.hide() }
            return false
        case .dismissPicker:
            overlay.hide()
            return true
        case .showPicker:
            let screen = Self.screen(containingAX: axLocation)
            let provider = settings.previewMode == .live ? thumbnails : nil
            Task { @MainActor [overlay] in
                overlay.show(app: app, windows: windows, on: screen, thumbnails: provider)
            }
            return true
        }
    }

    static func screen(containingAX point: CGPoint) -> NSScreen {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return NSScreen.main! }
        let cocoaPoint = ScreenGeometry.cocoaPoint(fromAX: point, primaryScreenHeight: primary.frame.height)
        if let index = ScreenGeometry.screenIndex(containing: cocoaPoint, screenFrames: screens.map(\.frame)) {
            return screens[index]
        }
        return NSScreen.main ?? primary
    }

    private func showSettings() {
        guard let updater else { return }
        if settingsWindow == nil {
            settingsWindow = WindowFactory.makeWindow(
                title: "Réglages DockPick",
                content: SettingsView(settings: settings, permissions: permissions, updater: updater)
            )
        }
        if let settingsWindow { WindowFactory.present(settingsWindow) }
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = WindowFactory.makeWindow(title: "Bienvenue dans DockPick", content: PermissionsView(permissions: permissions))
        }
        if let onboardingWindow { WindowFactory.present(onboardingWindow) }
    }
}
