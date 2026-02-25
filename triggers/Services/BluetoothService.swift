import Foundation
import AVFoundation
import CoreBluetooth
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "BluetoothService")

private let bluetoothPortTypes: Set<AVAudioSession.Port> = [
    .bluetoothA2DP, .bluetoothHFP, .bluetoothLE
]

@MainActor
final class BluetoothService: NSObject, ObservableObject, CBCentralManagerDelegate {

    static let shared = BluetoothService()

    /// Currently connected audio devices (AirPods, car, headphones) — used for rule firing.
    @Published var connectedPeripheralNames: Set<String> = []

    /// Devices discovered during a CBCentralManager scan — used for the picker UI.
    @Published var scannedDevices: [String] = []
    @Published var isScanning: Bool = false

    /// Fires with (device name, isConnected) when an audio route changes.
    var onDeviceEvent: ((String, Bool) -> Void)?

    private var centralManager: CBCentralManager?
    private var scanTimer: Timer?

    private override init() {
        super.init()
        let initial = Self.bluetoothPortNames(in: AVAudioSession.sharedInstance().currentRoute)
        connectedPeripheralNames = initial
        initial.forEach { KnownNetworksStore.shared.addBluetooth($0) }
        logger.info("BluetoothService init — connected audio: \(initial)")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeDidChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // MARK: - AVAudioSession (event detection for rules)

    @objc private nonisolated func routeDidChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let _ = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        let session = AVAudioSession.sharedInstance()
        let newPorts = Self.bluetoothPortNames(in: session.currentRoute)
        let oldPorts: Set<String>
        if let prev = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
            oldPorts = Self.bluetoothPortNames(in: prev)
        } else {
            oldPorts = []
        }

        let connected    = newPorts.subtracting(oldPorts)
        let disconnected = oldPorts.subtracting(newPorts)

        Task { @MainActor in
            for name in connected {
                self.connectedPeripheralNames.insert(name)
                KnownNetworksStore.shared.addBluetooth(name)
                FileLogger.shared.log("Bluetooth connected: \(name)", category: "Bluetooth")
                self.onDeviceEvent?(name, true)
            }
            for name in disconnected {
                self.connectedPeripheralNames.remove(name)
                FileLogger.shared.log("Bluetooth disconnected: \(name)", category: "Bluetooth")
                self.onDeviceEvent?(name, false)
            }
        }
    }

    // MARK: - CBCentralManager (scanning for device picker)

    func startScan() {
        scannedDevices = []
        isScanning = true
        if centralManager == nil {
            // Initialising triggers centralManagerDidUpdateState; scan begins there.
            centralManager = CBCentralManager(delegate: self, queue: nil,
                                              options: [CBCentralManagerOptionShowPowerAlertKey: false])
        } else if centralManager?.state == .poweredOn {
            centralManager?.scanForPeripherals(withServices: nil, options: nil)
        }
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopScan() }
        }
    }

    func stopScan() {
        centralManager?.stopScan()
        isScanning = false
        scanTimer?.invalidate()
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        Task { @MainActor in
            guard self.isScanning else { return }
            self.centralManager?.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let name = peripheral.name, !name.isEmpty else { return }
        Task { @MainActor in
            if !self.scannedDevices.contains(name) {
                self.scannedDevices.append(name)
                self.scannedDevices.sort()
            }
        }
    }

    // MARK: - Helpers

    private nonisolated static func bluetoothPortNames(in route: AVAudioSessionRouteDescription) -> Set<String> {
        Set(route.outputs
            .filter { bluetoothPortTypes.contains($0.portType) }
            .map { $0.portName })
    }
}
