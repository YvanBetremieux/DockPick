import Combine
import Foundation

enum OpenMode: String, CaseIterable, Identifiable {
    case focus, maximize, fullScreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focus: "Focus seul"
        case .maximize: "Agrandir sur l'écran"
        case .fullScreen: "Plein écran macOS"
        }
    }
}

enum PreviewMode: String, CaseIterable, Identifiable {
    case live, titlesOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .live: "Aperçus en direct"
        case .titlesOnly: "Titres seuls"
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings(defaults: .standard)

    enum Key {
        static let enabled = "enabled"
        static let openMode = "openMode"
        static let previewMode = "previewMode"
        static let includeMinimized = "includeMinimized"
        static let includeOtherSpaces = "includeOtherSpaces"
        static let excludedBundleIDs = "excludedBundleIDs"
    }

    static let defaultExcludedBundleIDs = ["com.apple.finder"]

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.openMode: OpenMode.focus.rawValue,
            Key.previewMode: PreviewMode.live.rawValue,
            Key.includeMinimized: true,
            Key.includeOtherSpaces: false,
            Key.excludedBundleIDs: Self.defaultExcludedBundleIDs,
        ])
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.enabled) }
    }

    var openMode: OpenMode {
        get { OpenMode(rawValue: defaults.string(forKey: Key.openMode) ?? "") ?? .focus }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: Key.openMode) }
    }

    var previewMode: PreviewMode {
        get { PreviewMode(rawValue: defaults.string(forKey: Key.previewMode) ?? "") ?? .live }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: Key.previewMode) }
    }

    var includeMinimized: Bool {
        get { defaults.bool(forKey: Key.includeMinimized) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.includeMinimized) }
    }

    var includeOtherSpaces: Bool {
        get { defaults.bool(forKey: Key.includeOtherSpaces) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.includeOtherSpaces) }
    }

    var excludedBundleIDs: [String] {
        get { defaults.stringArray(forKey: Key.excludedBundleIDs) ?? [] }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.excludedBundleIDs) }
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }
}
