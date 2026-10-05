import AppKit
import ApplicationServices
import Combine

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var screenRecordingGranted = CGPreflightScreenCaptureAccess()

    private var pollTimer: Timer?
    private var grantedCallbacks: [() -> Void] = []

    func refresh() {
        let accessibility = AXIsProcessTrusted()
        if accessibility != accessibilityGranted { accessibilityGranted = accessibility }
        let screen = CGPreflightScreenCaptureAccess()
        if screen != screenRecordingGranted { screenRecordingGranted = screen }
        if accessibility, !grantedCallbacks.isEmpty {
            let callbacks = grantedCallbacks
            grantedCallbacks = []
            pollTimer?.invalidate()
            pollTimer = nil
            callbacks.forEach { $0() }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    /// Appelle `action` dès que l'accessibilité est accordée (vérification toutes les secondes).
    func whenAccessibilityGranted(_ action: @escaping () -> Void) {
        if AXIsProcessTrusted() { action(); return }
        grantedCallbacks.append(action)
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }
}
