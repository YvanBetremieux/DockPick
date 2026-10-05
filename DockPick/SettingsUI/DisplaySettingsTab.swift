import SwiftUI

struct DisplaySettingsTab: View {
    @ObservedObject var settings: Settings

    var body: some View {
        Form {
            Picker("Contenu des cases", selection: $settings.previewMode) {
                ForEach(PreviewMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Inclure les fenêtres réduites", isOn: $settings.includeMinimized)
            Toggle("Inclure les fenêtres des autres Spaces", isOn: $settings.includeOtherSpaces)
            Text("Seules les fenêtres que l'app expose à l'accessibilité peuvent apparaître depuis les autres Spaces.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
