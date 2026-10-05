import AppKit
import ApplicationServices

@MainActor
final class DockClickMonitor {
    typealias Handler = (_ app: NSRunningApplication, _ axLocation: CGPoint) -> Bool

    private let handler: Handler
    private let systemWide = AXUIElementCreateSystemWide()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tracker = ClickSwallowTracker()

    init(handler: @escaping Handler) {
        self.handler = handler
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
    }

    /// Nécessite l'autorisation d'accessibilité ; renvoie false si le tap n'a pas pu être créé.
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: dockClickTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            let swallow = shouldSwallow(event)
            tracker.mouseDown(swallowed: swallow)
            return swallow ? nil : Unmanaged.passUnretained(event)
        case .leftMouseUp:
            return tracker.shouldSwallowMouseUp() ? nil : Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func shouldSwallow(_ event: CGEvent) -> Bool {
        guard ClickPolicy.isPlainClick(flags: event.flags, clickState: event.getIntegerValueField(.mouseEventClickState)) else {
            return false
        }
        let location = event.location
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(location.y), &hit) == .success,
              let element = hit,
              let pid = element.pid,
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dock"
        else { return false }

        let kind = DockItemClassifier.classify(
            role: element.string(kAXRoleAttribute),
            subrole: element.string(kAXSubroleAttribute),
            url: element.url(kAXURLAttribute)
        )
        guard case .application(let url) = kind, let app = Self.runningApplication(at: url) else { return false }
        return handler(app, location)
    }

    static func runningApplication(at url: URL) -> NSRunningApplication? {
        let target = url.resolvingSymlinksInPath().standardizedFileURL
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == target
        }
    }
}

/// Le tap est ajouté à la run loop principale : le callback s'exécute sur le thread principal.
private func dockClickTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<DockClickMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
}
