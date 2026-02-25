import SwiftUI

struct BluetoothTriggerConfigView: View {

    let type: TriggerType
    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var value: String = ""
    @ObservedObject private var bt = BluetoothService.shared

    private var listedDevices: [String] {
        var list = bt.scannedDevices
        for name in bt.connectedPeripheralNames.sorted() where !list.contains(name) {
            list.append(name)
        }
        for name in KnownNetworksStore.shared.bluetoothDevices where !list.contains(name) {
            list.append(name)
        }
        return list
    }

    var body: some View {
        Form {
            // Device list
            Section {
                if listedDevices.isEmpty && !bt.isScanning {
                    Text("No devices found yet. Tap Scan or enter a name below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listedDevices, id: \.self) { name in
                        Button {
                            value = name
                        } label: {
                            HStack {
                                Label(name, systemImage: "bluetooth")
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
                    if bt.isScanning {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text("Scanning…").foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(type == .bluetoothConnect ? "Connect to Device" : "Disconnect from Device")
                    Spacer()
                    Button(bt.isScanning ? "Stop" : "Scan") {
                        bt.isScanning ? bt.stopScan() : bt.startScan()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            } footer: {
                Text("Shows nearby advertising devices and connected audio devices (AirPods, headphones, car).")
                    .font(.caption)
            }

            // Manual entry fallback
            Section {
                TextField("Device name", text: $value)
                    .autocorrectionDisabled()
            } header: {
                Text("Or enter name manually")
            }
        }
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { bt.stopScan() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    config.bluetoothDeviceName = trimmed
                    KnownNetworksStore.shared.addBluetooth(trimmed)
                    onAdd()
                }
                .fontWeight(.semibold)
                .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
