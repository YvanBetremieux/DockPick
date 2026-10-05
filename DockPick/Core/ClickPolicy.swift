import CoreGraphics

enum ClickDecision: Equatable {
    case passThrough
    case showPicker
    case dismissPicker
}

struct ClickContext {
    var enabled: Bool
    var isExcluded: Bool
    var windowCount: Int
    var pickerVisibleForThisApp: Bool
}

enum ClickPolicy {
    static func decide(_ context: ClickContext) -> ClickDecision {
        if context.pickerVisibleForThisApp { return .dismissPicker }
        guard context.enabled, !context.isExcluded, context.windowCount >= 2 else { return .passThrough }
        return .showPicker
    }

    /// Clic simple sans modificateur : ⌘/⌥/⌃/⇧ et double-clic gardent leur sens Dock habituel.
    static func isPlainClick(flags: CGEventFlags, clickState: Int64) -> Bool {
        clickState == 1 && flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty
    }
}
