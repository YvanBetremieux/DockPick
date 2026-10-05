/// Garantit qu'un mouseDown avalé est suivi d'un mouseUp avalé, et rien de plus.
struct ClickSwallowTracker {
    private var pendingUp = false

    mutating func mouseDown(swallowed: Bool) {
        pendingUp = swallowed
    }

    mutating func shouldSwallowMouseUp() -> Bool {
        defer { pendingUp = false }
        return pendingUp
    }
}
