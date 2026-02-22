import Foundation
import CoreBluetooth
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "BluetoothService")

@MainActor
final class BluetoothService: NSObject, ObservableObject, CBCentralManagerDelegate {

    static let shared = BluetoothService()

    private var centralManager: CBCentralManager!
    @Published var state: CBManagerState = .unknown
    @Published var connectedPeripheralNames: Set<String> = []

    /// Fires with (device name, isConnected)
    var onDeviceEvent: ((String, Bool) -> Void)?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let currentState = central.state
        Task { @MainActor in
            self.state = currentState
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        guard let name = peripheral.name else { return }
        logger.info("Bluetooth connected: \(name)")
        Task { @MainActor in
            self.connectedPeripheralNames.insert(name)
            self.onDeviceEvent?(name, true)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        guard let name = peripheral.name else { return }
        logger.info("Bluetooth disconnected: \(name)")
        Task { @MainActor in
            self.connectedPeripheralNames.remove(name)
            self.onDeviceEvent?(name, false)
        }
    }
}
