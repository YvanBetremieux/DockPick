import SwiftUI

struct AdvancedSettingsTab: View {
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("Retire DockPick du démarrage, supprime ses réglages et autorisations, puis place l'app dans la Corbeille.")
                    .foregroundStyle(.secondary)
                Button("Désinstaller DockPick…", role: .destructive) {
                    Uninstaller.confirmAndUninstall()
                }
            }
        }
        .formStyle(.grouped)
    }
}
