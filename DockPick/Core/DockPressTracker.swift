import CoreGraphics

enum PressAction: Equatable {
    /// Laisser passer l'événement courant.
    case pass
    /// Avaler l'événement courant.
    case swallow
    /// Clic rapide confirmé : avaler et exécuter la décision prise au mouseDown.
    case commit
    /// Rendre au Dock l'appui retenu puis l'événement courant (glisser, relâchement tardif).
    case replayPressThenCurrent
    /// Rendre au Dock l'appui retenu (appui prolongé : menu du Dock).
    case replayPress
    /// Rien à faire.
    case none
}

/// Retient l'appui sur une icône interceptée jusqu'à savoir s'il s'agit d'un clic,
/// d'un glisser ou d'un appui prolongé — ces deux derniers sont rendus au Dock.
struct DockPressTracker {
    static let maxClickDuration: Double = 0.4
    static let maxClickDistance: CGFloat = 4

    private var pending: (time: Double, location: CGPoint)?

    var hasPendingPress: Bool { pending != nil }

    mutating func mouseDown(intercept: Bool, time: Double, location: CGPoint) -> PressAction {
        pending = intercept ? (time, location) : nil
        return intercept ? .swallow : .pass
    }

    mutating func mouseDragged(location: CGPoint) -> PressAction {
        guard let pending else { return .pass }
        let distance = hypot(location.x - pending.location.x, location.y - pending.location.y)
        guard distance > Self.maxClickDistance else { return .swallow }
        self.pending = nil
        return .replayPressThenCurrent
    }

    mutating func mouseUp(time: Double) -> PressAction {
        guard let pending else { return .pass }
        self.pending = nil
        return time - pending.time <= Self.maxClickDuration ? .commit : .replayPressThenCurrent
    }

    mutating func holdTimerFired(time: Double) -> PressAction {
        guard let pending, time - pending.time >= Self.maxClickDuration else { return .none }
        self.pending = nil
        return .replayPress
    }
}
