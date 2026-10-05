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
        Self.log.info("Accessibilité accordée")
        menuBar?.refreshIcon()
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = WindowFactory.makeWindow(title: "Bienvenue dans DockPick", content: PermissionsView(permissions: permissions))
        }
        if let onboardingWindow { WindowFactory.present(onboardingWindow) }
    }
}
