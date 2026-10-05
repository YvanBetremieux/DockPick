import AppKit
import SwiftUI

enum WindowFactory {
    @MainActor
    static func makeWindow<Content: View>(title: String, content: Content) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    @MainActor
    static func present(_ window: NSWindow) {
        // Appelé depuis le menu de la barre d'état : on attend la fin du suivi du menu,
        // sinon macOS ignore l'activation et la fenêtre reste derrière.
        DispatchQueue.main.async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
