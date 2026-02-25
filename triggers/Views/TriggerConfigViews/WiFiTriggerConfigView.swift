import SwiftUI

struct WiFiTriggerConfigView: View {

    let type: TriggerType
    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var value: String = ""

    private var networks: [String] {
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
            // Network list
            if !networks.isEmpty {
                Section {
                    ForEach(networks, id: \.self) { name in
                        Button {
                            value = name
                        } label: {
                            HStack {
                                Label(name, systemImage: "wifi")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if value == name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(type == .wifiConnect ? "Connect to Network" : "Disconnect from Network")
                } footer: {
                    Text("iOS doesn't expose nearby network scanning. Only your current and previously used networks appear here.")
                        .font(.caption)
                }
            }

            // Manual entry fallback
            Section {
                TextField("Network name (SSID)", text: $value)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text(networks.isEmpty ? "Network name (SSID)" : "Or enter name manually")
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
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    config.wifiSSID = trimmed
                    KnownNetworksStore.shared.addWifi(trimmed)
                    onAdd()
                }
                .fontWeight(.semibold)
                .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
