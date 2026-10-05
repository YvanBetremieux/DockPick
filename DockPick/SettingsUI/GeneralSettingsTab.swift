import SwiftUI

struct GeneralSettingsTab: View {
    @ObservedObject var settings: Settings
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Toggle("Activer DockPick", isOn: $settings.enabled)
            Toggle("Lancer au démarrage", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    guard newValue != LoginItem.isEnabled else { return }
                    do {
                        try LoginItem.setEnabled(newValue)
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = LoginItem.isEnabled
                    }
                }
            if let loginError {
                Text(loginError).font(.footnote).foregroundStyle(.red)
            }
            Picker("Action à l'ouverture d'une fenêtre", selection: $settings.openMode) {
                ForEach(OpenMode.allCases) { Text($0.label).tag($0) }
            }
        }
        .formStyle(.grouped)
    }
}
