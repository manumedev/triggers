import Foundation

/// Persists WiFi SSIDs and Bluetooth device names that have been used in rules,
/// so the trigger config views can offer them as quick-select options.
final class KnownNetworksStore: @unchecked Sendable {

    static let shared = KnownNetworksStore()

    private let wifiKey = "knownWifiSSIDs"
    private let bluetoothKey = "knownBluetoothDevices"
    private let defaults = UserDefaults.standard

    private init() {}

    var wifiSSIDs: [String] {
        get { defaults.stringArray(forKey: wifiKey) ?? [] }
        set { defaults.set(newValue, forKey: wifiKey) }
    }

    var bluetoothDevices: [String] {
        get { defaults.stringArray(forKey: bluetoothKey) ?? [] }
        set { defaults.set(newValue, forKey: bluetoothKey) }
    }

    func addWifi(_ ssid: String) {
        let trimmed = ssid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !wifiSSIDs.contains(trimmed) else { return }
        wifiSSIDs = ([trimmed] + wifiSSIDs).prefix(20).map { $0 }
    }

    func addBluetooth(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !bluetoothDevices.contains(trimmed) else { return }
        bluetoothDevices = ([trimmed] + bluetoothDevices).prefix(20).map { $0 }
    }
}
