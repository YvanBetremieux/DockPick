import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DockPick a besoin de deux autorisations")
                .font(.title2.bold())
            PermissionRow(
                title: "Accessibilité",
                detail: "Indispensable : détecter les clics sur le Dock et activer les fenêtres.",
                granted: permissions.accessibilityGranted,
                action: permissions.requestAccessibility
            )
            PermissionRow(
                title: "Enregistrement d'écran",
                detail: "Optionnelle : afficher les aperçus des fenêtres. Sans elle, seuls les titres sont affichés.",
                granted: permissions.screenRecordingGranted,
                action: permissions.requestScreenRecording
            )
            Text("Après avoir accordé l'enregistrement d'écran, macOS peut demander de relancer DockPick.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 520, alignment: .leading)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            permissions.refresh()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.title2)
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).bold()
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Autoriser…", action: action)
            }
        }
    }
}
