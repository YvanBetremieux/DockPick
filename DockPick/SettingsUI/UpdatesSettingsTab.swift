import SwiftUI

struct UpdatesSettingsTab: View {
    @ObservedObject var updater: UpdaterController

    var body: some View {
        Form {
            Toggle("Rechercher automatiquement les mises à jour (chaque jour)", isOn: $updater.automaticallyChecks)
            Toggle("Installer automatiquement les mises à jour", isOn: $updater.automaticallyDownloads)
                .disabled(!updater.automaticallyChecks)
            HStack {
                Button("Rechercher maintenant") { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
                Spacer()
                Text("Version \(AppInfo.version) (\(AppInfo.build))").foregroundStyle(.secondary)
            }
            if let lastCheck = updater.lastCheck {
                Text("Dernière vérification : \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
