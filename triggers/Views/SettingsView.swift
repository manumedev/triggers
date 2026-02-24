import SwiftUI

struct SettingsView: View {

    @State private var notificationStatus: String = "Checking…"
    @State private var locationStatus: String = "Checking…"

    var body: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Notifications", value: notificationStatus)
                LabeledContent("Location (Always)", value: locationStatus)

                Button("Open System Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section("Saved Places") {
                NavigationLink("Manage Places") {
                    PlacesView()
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                LabeledContent("Active Geofences", value: "\(LocationService.shared.monitoredRegionCount) / 20")
            }
        }
        .navigationTitle("Settings")
        .task {
            await refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() async {
        let notif = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = notif.authorizationStatus == .authorized ? "Allowed" : "Not Allowed"

        let locAuth = LocationService.shared.authorizationStatus
        switch locAuth {
        case .authorizedAlways:   locationStatus = "Always Allowed"
        case .authorizedWhenInUse: locationStatus = "When In Use Only"
        case .denied:              locationStatus = "Denied"
        case .notDetermined:       locationStatus = "Not Set"
        default:                   locationStatus = "Unknown"
        }
    }
}
