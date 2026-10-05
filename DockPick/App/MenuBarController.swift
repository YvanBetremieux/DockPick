import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    struct Actions {
        var openSettings: (() -> Void)?
        var checkForUpdates: (() -> Void)?
        var requestAccessibility: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: Settings
    private let permissions: PermissionsManager
    private let actions: Actions
    /// Faux si l'interception du Dock n'a pas pu démarrer.
    var monitorActive = true { didSet { refreshIcon() } }

    init(settings: Settings, permissions: PermissionsManager, actions: Actions) {
        self.settings = settings
        self.permissions = permissions
        self.actions = actions
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()
    }

    func refreshIcon() {
        let symbol = permissions.accessibilityGranted && monitorActive ? "rectangle.split.2x2" : "exclamationmark.triangle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DockPick")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !settings.enabled
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        permissions.refresh()
        menu.removeAllItems()

        let toggle = item("Activer DockPick", #selector(toggleEnabled))
        toggle.state = settings.enabled ? .on : .off
        menu.addItem(toggle)

        if !permissions.accessibilityGranted {
            menu.addItem(item("Autoriser l'accessibilité…", #selector(requestAccessibility)))
        }

        menu.addItem(.separator())
        if actions.checkForUpdates != nil {
            menu.addItem(item("Rechercher les mises à jour…", #selector(checkForUpdates)))
        }
        if actions.openSettings != nil {
            menu.addItem(item("Réglages…", #selector(openSettings), key: ","))
        }
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quitter DockPick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        refreshIcon()
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        refreshIcon()
    }

    @objc private func requestAccessibility() { actions.requestAccessibility() }
    @objc private func checkForUpdates() { actions.checkForUpdates?() }
    @objc private func openSettings() { actions.openSettings?() }
}
