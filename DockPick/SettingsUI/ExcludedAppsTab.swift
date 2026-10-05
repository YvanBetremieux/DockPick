import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsTab: View {
    @ObservedObject var settings: Settings
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pour ces apps, un clic sur le Dock garde son comportement normal.")
                .foregroundStyle(.secondary)
            List(selection: $selection) {
                ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Image(nsImage: AppLookup.icon(for: bundleID)).resizable().frame(width: 20, height: 20)
                        Text(AppLookup.name(for: bundleID))
                        Spacer()
                        Text(bundleID).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(bundleID)
                }
            }
            HStack(spacing: 4) {
                Button { addApps() } label: { Image(systemName: "plus") }
                Button {
                    guard let selection else { return }
                    settings.excludedBundleIDs.removeAll { $0 == selection }
                    self.selection = nil
                } label: { Image(systemName: "minus") }
                .disabled(selection == nil)
            }
        }
        .padding()
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier, !settings.excludedBundleIDs.contains(bundleID) {
                settings.excludedBundleIDs.append(bundleID)
            }
        }
    }
}

enum AppLookup {
    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}
