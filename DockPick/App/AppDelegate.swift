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
    private var monitor: DockClickMonitor?
    private var menuBar: MenuBarController?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        menuBar = MenuBarController(
            settings: settings,
            permissions: permissions,
            actions: .init(
                openSettings: nil,
                checkForUpdates: nil,
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
        let windows = settings.enabled && !excluded ? catalog.windows(for: app) : []
        let decision = ClickPolicy.decide(ClickContext(
            enabled: settings.enabled,
            isExcluded: excluded,
            windowCount: windows.count,
            pickerVisibleForThisApp: false
        ))
        let titles = windows.map(\.info.title).joined(separator: " | ")
        Self.log.debug("Clic Dock \(app.bundleIdentifier ?? "?", privacy: .public) : \(windows.count) fenêtres → \(String(describing: decision), privacy: .public) [\(titles, privacy: .public)]")
        return decision == .showPicker
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = WindowFactory.makeWindow(title: "Bienvenue dans DockPick", content: PermissionsView(permissions: permissions))
        }
        if let onboardingWindow { WindowFactory.present(onboardingWindow) }
    }
}
