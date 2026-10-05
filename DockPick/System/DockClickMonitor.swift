import AppKit
import ApplicationServices

@MainActor
final class DockClickMonitor {
    /// Renvoie l'action à exécuter si le clic doit être intercepté (afficher ou fermer la vue), sinon nil.
    typealias Handler = (_ app: NSRunningApplication, _ axLocation: CGPoint) -> (() -> Void)?

    /// Marque les événements rejoués au Dock pour que le tap les laisse passer.
    private static let replayMarker: Int64 = 0x444F_434B

    private let handler: Handler
    private let shouldInspect: () -> Bool
    private let dock = DockAccessor()
    private let systemWide = AXUIElementCreateSystemWide()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressTracker = DockPressTracker()
    private var pendingDown: CGEvent?
    private var pendingCommit: (() -> Void)?
    private var holdTimer: DispatchWorkItem?

    /// `shouldInspect` évite tout travail AX quand DockPick est en pause.
    init(shouldInspect: @escaping () -> Bool, handler: @escaping Handler) {
        self.shouldInspect = shouldInspect
        self.handler = handler
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
    }

    var isRunning: Bool { tap != nil }

    /// Nécessite l'autorisation d'accessibilité ; renvoie false si le tap n'a pas pu être créé.
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .leftMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
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
        clearPending()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == Self.replayMarker {
            return Unmanaged.passUnretained(event)
        }
        let now = ProcessInfo.processInfo.systemUptime
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            let commit = inspect(event)
            let action = pressTracker.mouseDown(intercept: commit != nil, time: now, location: event.location)
            clearPending()
            if let commit {
                pendingDown = event.copy()
                pendingCommit = commit
                scheduleHoldTimer()
            }
            return apply(action, to: event)
        case .leftMouseDragged:
            return apply(pressTracker.mouseDragged(location: event.location), to: event)
        case .leftMouseUp:
            return apply(pressTracker.mouseUp(time: now), to: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func apply(_ action: PressAction, to event: CGEvent) -> Unmanaged<CGEvent>? {
        switch action {
        case .pass, .none:
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .commit:
            let commit = pendingCommit
            clearPending()
            DispatchQueue.main.async { commit?() }
            return nil
        case .replayPressThenCurrent:
            // L'événement courant est rejoué après l'appui, pour que le Dock les reçoive dans l'ordre.
            replayPendingPress()
            Self.replay(event)
            return nil
        case .replayPress:
            replayPendingPress()
            return Unmanaged.passUnretained(event)
        }
    }

    private func scheduleHoldTimer() {
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.pressTracker.holdTimerFired(time: ProcessInfo.processInfo.systemUptime) == .replayPress {
                    self.replayPendingPress()
                }
            }
        }
        holdTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + DockPressTracker.maxClickDuration + 0.02, execute: work)
    }

    private func replayPendingPress() {
        if let pendingDown { Self.replay(pendingDown) }
        clearPending()
    }

    private func clearPending() {
        holdTimer?.cancel()
        holdTimer = nil
        pendingDown = nil
        pendingCommit = nil
    }

    private static func replay(_ event: CGEvent) {
        guard let copy = event.copy() else { return }
        copy.setIntegerValueField(.eventSourceUserData, value: replayMarker)
        copy.post(tap: .cgSessionEventTap)
    }

    private func inspect(_ event: CGEvent) -> (() -> Void)? {
        guard shouldInspect(),
              ClickPolicy.isPlainClick(flags: event.flags, clickState: event.getIntegerValueField(.mouseEventClickState))
        else { return nil }
        let location = event.location
        // Filtre bon marché : seul un clic sur la barre d'icônes déclenche un hit-test AX.
        guard let strip = dock.iconStripFrame(), strip.insetBy(dx: -2, dy: -2).contains(location) else { return nil }

        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(location.y), &hit) == .success,
              let element = hit,
              element.pid == dock.pid
        else { return nil }

        let kind = DockItemClassifier.classify(
            role: element.string(kAXRoleAttribute),
            subrole: element.string(kAXSubroleAttribute),
            url: element.url(kAXURLAttribute)
        )
        guard case .application(let url) = kind, let app = Self.runningApplication(at: url) else { return nil }
        return handler(app, location)
    }

    static func runningApplication(at url: URL) -> NSRunningApplication? {
        let target = url.resolvingSymlinksInPath().standardizedFileURL
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == target
        }
    }

    /// Cadre de la barre d'icônes du Dock (coordonnées AX), pour que la vue ne passe pas dessous.
    func dockIconStripFrame() -> CGRect? {
        dock.iconStripFrame()
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
