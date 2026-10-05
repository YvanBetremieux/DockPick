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
    private var monitorRetryTimer: Timer?

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
        startMonitor()
    }

    private func startMonitor() {
        if monitor == nil {
            monitor = DockClickMonitor(
                shouldInspect: { [weak self] in
                    guard let self else { return false }
                    return self.settings.enabled || self.overlay.isVisible
                },
                handler: { [weak self] app, location in
                    self?.handleDockClick(app: app, axLocation: location)
                }
            )
        }
        guard let monitor, !monitor.isRunning else { return }
        if monitor.start() {
            Self.log.info("Surveillance du Dock démarrée")
            monitorRetryTimer?.invalidate()
            monitorRetryTimer = nil
            menuBar?.monitorActive = true
        } else {
            // Juste après l'octroi de l'accessibilité, macOS refuse parfois le tap : on réessaie.
            Self.log.error("Impossible de créer l'event tap, nouvel essai dans 2 s")
            menuBar?.monitorActive = false
            guard monitorRetryTimer == nil else { return }
            monitorRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.startMonitor() }
            }
        }
    }

    private func handleDockClick(app: NSRunningApplication, axLocation: CGPoint) -> (() -> Void)? {
        let excluded = settings.isExcluded(app.bundleIdentifier)
        let pickerForThisApp = overlay.isVisible && overlay.currentPID == app.processIdentifier
        let eligible = settings.enabled && !excluded && !pickerForThisApp
        let windows = eligible ? (catalog.windows(for: app) ?? []) : []
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
            return nil
        case .dismissPicker:
            return { [overlay] in overlay.hide() }
        case .showPicker:
            let screen = Self.screen(containingAX: axLocation)
            let dockFrame = monitor?.dockIconStripFrame()
            let provider = settings.previewMode == .live ? thumbnails : nil
            return { [overlay] in
                overlay.show(app: app, windows: windows, on: screen, dockFrame: dockFrame, thumbnails: provider)
            }
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
