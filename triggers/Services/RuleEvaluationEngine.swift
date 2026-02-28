import Foundation
import SwiftData
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "RuleEvaluationEngine")

/// Evaluates WiFi, Location, and Bluetooth rules and fires notifications when conditions are met.
@MainActor
final class RuleEvaluationEngine: ObservableObject {

    static let shared = RuleEvaluationEngine()

    private weak var modelContext: ModelContext?

    private let location  = LocationService.shared
    private let wifi      = WiFiMonitorService.shared
    private let bluetooth = BluetoothService.shared
    private let notify    = NotificationService.shared

    /// Guards against duplicate fires when the same event is delivered multiple times
    /// (e.g. CLLocationManager re-delivering boundary events, NWPathMonitor oscillation).
    private var recentFires: [UUID: Date] = [:]
    private let dedupWindow: TimeInterval = 10

    private func shouldFire(rule: Rule) -> Bool {
        if let last = recentFires[rule.id], Date().timeIntervalSince(last) < dedupWindow {
            FileLogger.shared.log("  '\(rule.name)': dedup skip (\(Int(Date().timeIntervalSince(last)))s ago)", category: "Eval")
            return false
        }
        recentFires[rule.id] = Date()
        return true
    }

    private init() {}

    // MARK: - Setup

    func start(modelContext: ModelContext) {
        self.modelContext = modelContext
        wireCallbacks()
        let rules = fetchEnabledRules(from: modelContext)
        let msg = "Engine started — \(rules.count) enabled rule(s)"
        logger.info("\(msg)")
        FileLogger.shared.log(msg, category: "Engine")
    }

    // MARK: - Callbacks

    private func wireCallbacks() {
        location.onRegionEvent = { [weak self] regionId, isEntry in
            self?.handleLocationEvent(regionId: regionId, isEntry: isEntry)
        }
        wifi.onSSIDEvent = { [weak self] ssid, isConnected in
            self?.handleWiFiEvent(ssid: ssid, isConnected: isConnected)
        }
        bluetooth.onDeviceEvent = { [weak self] deviceName, isConnected in
            self?.handleBluetoothEvent(deviceName: deviceName, isConnected: isConnected)
        }
    }

    // MARK: - Event handlers

    private func handleLocationEvent(regionId: String, isEntry: Bool) {
        let type: TriggerType = isEntry ? .locationArrive : .locationLeave
        let msg = "Location event: \(type.rawValue), region=\(regionId)"
        logger.info("\(msg)")
        FileLogger.shared.log(msg, category: "Location")
        evaluateLocation(regionId: regionId, triggerType: type)
    }

    private func handleWiFiEvent(ssid: String?, isConnected: Bool) {
        let type: TriggerType = isConnected ? .wifiConnect : .wifiDisconnect
        let msg = "WiFi event: \(type.rawValue), ssid=\(ssid ?? "nil")"
        logger.info("\(msg)")
        FileLogger.shared.log(msg, category: "WiFi")
        evaluateWiFi(ssid: ssid, triggerType: type)
    }

    private func handleBluetoothEvent(deviceName: String, isConnected: Bool) {
        let type: TriggerType = isConnected ? .bluetoothConnect : .bluetoothDisconnect
        let msg = "Bluetooth event: \(type.rawValue), device=\(deviceName)"
        logger.info("\(msg)")
        FileLogger.shared.log(msg, category: "Bluetooth")
        evaluateBluetooth(deviceName: deviceName, triggerType: type)
    }

    // MARK: - Evaluation

    private func evaluateLocation(regionId: String, triggerType: TriggerType) {
        guard let context = modelContext else { return }
        let rules = fetchEnabledRules(from: context)
        FileLogger.shared.log("Location \(triggerType.rawValue) region=\(regionId): \(rules.count) rules", category: "Eval")
        for rule in rules {
            guard rule.canFire() else {
                FileLogger.shared.log("  '\(rule.name)': skipped (canFire=false)", category: "Eval")
                continue
            }
            let fired = evaluateRule(rule, eventType: triggerType) { cond in
                cond.type == triggerType && cond.config.placeId?.uuidString == regionId
            }
            FileLogger.shared.log("  '\(rule.name)': fired=\(fired)", category: "Eval")
            if fired && shouldFire(rule: rule) { Task { await notify.fire(rule: rule) } }
        }
    }

    private func evaluateWiFi(ssid: String?, triggerType: TriggerType) {
        guard let context = modelContext else {
            let msg = "evaluateWiFi: modelContext is nil — no evaluation possible"
            logger.error("\(msg)")
            FileLogger.shared.log(msg, category: "Eval")
            return
        }
        let rules = fetchEnabledRules(from: context)
        let evalMsg = "Eval WiFi \(triggerType.rawValue) ssid=\(ssid ?? "nil"): \(rules.count) rules"
        logger.info("\(evalMsg)")
        FileLogger.shared.log(evalMsg, category: "Eval")
        for rule in rules {
            let conditions = rule.conditions
            let condSummary = conditions.map { "\($0.type.rawValue)(ssid=\($0.config.wifiSSID ?? "any"))" }.joined(separator: ",")
            FileLogger.shared.log("  '\(rule.name)' logic=\(rule.conditionLogic) canFire=\(rule.canFire()) conditions=[\(condSummary)]", category: "Eval")
            guard rule.canFire() else {
                logger.info("  '\(rule.name)': skipped (canFire=false)")
                continue
            }
            let fired = evaluateRule(rule, eventType: triggerType) { cond in
                guard cond.type == triggerType else { return false }
                if let configured = cond.config.wifiSSID {
                    let match = configured == ssid
                    FileLogger.shared.log("    cond \(cond.type.rawValue) configured='\(configured)' event='\(ssid ?? "nil")' match=\(match)", category: "Eval")
                    return match
                }
                return true
            }
            logger.info("  '\(rule.name)': fired=\(fired)")
            FileLogger.shared.log("  '\(rule.name)': fired=\(fired)", category: "Eval")
            if fired && shouldFire(rule: rule) { Task { await notify.fire(rule: rule) } }
        }
    }

    private func evaluateBluetooth(deviceName: String, triggerType: TriggerType) {
        guard let context = modelContext else { return }
        let rules = fetchEnabledRules(from: context)
        let evalMsg = "Eval Bluetooth \(triggerType.rawValue) device='\(deviceName)': \(rules.count) rules"
        logger.info("\(evalMsg)")
        FileLogger.shared.log(evalMsg, category: "Eval")
        for rule in rules {
            guard rule.canFire() else {
                FileLogger.shared.log("  '\(rule.name)': skipped (canFire=false)", category: "Eval")
                continue
            }
            let fired = evaluateRule(rule, eventType: triggerType) { cond in
                guard cond.type == triggerType else { return false }
                // nil device name in config = match any device
                if let configured = cond.config.bluetoothDeviceName {
                    let match = configured == deviceName
                    FileLogger.shared.log("    cond \(cond.type.rawValue) configured='\(configured)' event='\(deviceName)' match=\(match)", category: "Eval")
                    return match
                }
                return true
            }
            logger.info("  '\(rule.name)': fired=\(fired)")
            FileLogger.shared.log("  '\(rule.name)': fired=\(fired)", category: "Eval")
            if fired && shouldFire(rule: rule) { Task { await notify.fire(rule: rule) } }
        }
    }

    // MARK: - AND/OR core logic

    private func evaluateRule(
        _ rule: Rule,
        eventType: TriggerType,
        matchCondition: (Condition) -> Bool
    ) -> Bool {
        let conditions = rule.conditions
        guard !conditions.isEmpty else { return false }

        // If no condition is relevant to this event (by type AND parameters), don't fire.
        // This prevents a WiFi event from triggering a Location/Bluetooth rule, and prevents
        // a WiFi event for "XYZ" from triggering a rule configured for "ABC".
        guard conditions.contains(where: { matchCondition($0) }) else { return false }

        switch rule.conditionLogic {
        case .or:
            // Guard above already confirmed at least one condition matches.
            return true
        case .and:
            // The current event satisfies at least one condition (verified by guard).
            // All remaining conditions must also be currently satisfied.
            return conditions.allSatisfy { matchCondition($0) || isConditionCurrentlyMet($0) }
        }
    }

    /// Live-state check for AND rules where co-conditions must also be satisfied.
    private func isConditionCurrentlyMet(_ condition: Condition) -> Bool {
        switch condition.type {
        case .wifiConnect:
            let ssid = wifi.currentSSID
            let connected = ssid != nil || wifi.isConnectedToWiFi
            if let configured = condition.config.wifiSSID { return connected && configured == ssid }
            return connected
        case .wifiDisconnect:
            let ssid = wifi.currentSSID
            let connected = ssid != nil || wifi.isConnectedToWiFi
            if let configured = condition.config.wifiSSID { return !connected || ssid != configured }
            return !connected
        case .bluetoothConnect:
            let name = condition.config.bluetoothDeviceName
            if let name { return bluetooth.connectedPeripheralNames.contains(name) }
            return !bluetooth.connectedPeripheralNames.isEmpty
        case .bluetoothDisconnect:
            let name = condition.config.bluetoothDeviceName
            if let name { return !bluetooth.connectedPeripheralNames.contains(name) }
            return bluetooth.connectedPeripheralNames.isEmpty
        default:
            return false
        }
    }

    // MARK: - Helpers

    private func fetchEnabledRules(from context: ModelContext) -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(predicate: #Predicate { $0.isEnabled })
        return (try? context.fetch(descriptor)) ?? []
    }
}
