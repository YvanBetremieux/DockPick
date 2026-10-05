import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var updater: UpdaterController

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem { Label("Général", systemImage: "gearshape") }
            DisplaySettingsTab(settings: settings)
                .tabItem { Label("Affichage", systemImage: "rectangle.split.2x2") }
            ExcludedAppsTab(settings: settings)
                .tabItem { Label("Apps exclues", systemImage: "nosign") }
            UpdatesSettingsTab(updater: updater)
                .tabItem { Label("Mises à jour", systemImage: "arrow.down.circle") }
            PermissionsView(permissions: permissions)
                .tabItem { Label("Autorisations", systemImage: "lock.shield") }
            AdvancedSettingsTab()
                .tabItem { Label("Avancé", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 600, height: 400)
        .padding()
    }
}
