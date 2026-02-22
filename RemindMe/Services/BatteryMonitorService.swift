import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "BatteryMonitorService")

@MainActor
final class BatteryMonitorService: ObservableObject {

    static let shared = BatteryMonitorService()

    @Published var batteryLevel: Float = 1.0          // 0.0 – 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown

    /// Fires with (level: Float, isCharging: Bool)
    var onBatteryEvent: ((Float, Bool) -> Void)?

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let rawLevel = UIDevice.current.batteryLevel
        batteryLevel = rawLevel < 0 ? 1.0 : rawLevel   // -1 means unknown (simulator / not yet ready)
        batteryState = UIDevice.current.batteryState

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func batteryLevelDidChange() {
        FileLogger.shared.assertMainThread()
        let raw = UIDevice.current.batteryLevel
        guard raw >= 0 else { return }  // -1 means unknown; ignore
        let level = raw
        batteryLevel = level
        logger.debug("Battery level: \(Int(level * 100))%")
        onBatteryEvent?(level, batteryState == .charging || batteryState == .full)
    }

    @objc private func batteryStateDidChange() {
        FileLogger.shared.assertMainThread()
        let state = UIDevice.current.batteryState
        batteryState = state
        logger.debug("Battery state changed: \(state.rawValue)")
        onBatteryEvent?(batteryLevel, state == .charging || state == .full)
    }

    var isCharging: Bool {
        batteryState == .charging || batteryState == .full
    }

    var isFull: Bool {
        batteryState == .full
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
