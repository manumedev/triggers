import SwiftUI

struct WiFiTriggerConfigView: View {

    let type: TriggerType
    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var ssid: String = ""

    private var suggestions: [String] {
        var list: [String] = []
        if let current = WiFiMonitorService.shared.currentSSID {
            list.append(current)
        }
        for known in KnownNetworksStore.shared.wifiSSIDs where !list.contains(known) {
            list.append(known)
        }
        return list
    }

    var body: some View {
        Form {
            if !suggestions.isEmpty {
                Section("Known Networks") {
                    ForEach(suggestions, id: \.self) { name in
                        Button {
                            ssid = name
                        } label: {
                            HStack {
                                Label(name, systemImage: "wifi")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if ssid == name {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                TextField("Network name (SSID)", text: $ssid)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text(type == .wifiConnect ? "Connect to WiFi" : "Disconnect from WiFi")
            } footer: {
                Text(suggestions.isEmpty
                     ? "Connect to a WiFi network first to see it suggested here."
                     : "Select a network above or type a name manually.")
            }
        }
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    let trimmed = ssid.trimmingCharacters(in: .whitespaces)
                    config.wifiSSID = trimmed
                    KnownNetworksStore.shared.addWifi(trimmed)
                    onAdd()
                }
                .fontWeight(.semibold)
                .disabled(ssid.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
