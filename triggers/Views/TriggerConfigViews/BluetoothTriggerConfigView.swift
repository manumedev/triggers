import SwiftUI

struct BluetoothTriggerConfigView: View {

    let type: TriggerType
    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var deviceName: String = ""

    private var suggestions: [String] {
        var list = BluetoothService.shared.connectedPeripheralNames.sorted()
        for known in KnownNetworksStore.shared.bluetoothDevices where !list.contains(known) {
            list.append(known)
        }
        return list
    }

    var body: some View {
        Form {
            if !suggestions.isEmpty {
                Section("Known Devices") {
                    ForEach(suggestions, id: \.self) { name in
                        Button {
                            deviceName = name
                        } label: {
                            HStack {
                                Label(name, systemImage: "bluetooth")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if deviceName == name {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                TextField("Device name", text: $deviceName)
                    .autocorrectionDisabled()
            } header: {
                Text(type == .bluetoothConnect ? "Connect to Device" : "Disconnect from Device")
            } footer: {
                Text(suggestions.isEmpty
                     ? "Connect your Bluetooth device first to see it suggested here."
                     : "Select a device above or type a name manually.")
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
                    let trimmed = deviceName.trimmingCharacters(in: .whitespaces)
                    config.bluetoothDeviceName = trimmed
                    KnownNetworksStore.shared.addBluetooth(trimmed)
                    onAdd()
                }
                .fontWeight(.semibold)
                .disabled(deviceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
