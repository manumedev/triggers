import Foundation
import SwiftData
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "RuleEvaluationEngine")

/// Evaluates WiFi and Location rules and fires notifications when conditions are met.
@MainActor
final class RuleEvaluationEngine: ObservableObject {

    static let shared = RuleEvaluationEngine()

    private weak var modelContext: ModelContext?

    private let location = LocationService.shared
    private let wifi     = WiFiMonitorService.shared
    private let notify   = NotificationService.shared

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
            if fired { Task { await notify.fire(rule: rule) } }
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
            if fired { Task { await notify.fire(rule: rule) } }
        }
    }

    // MARK: - AND/OR core logic

    private func evaluateRule(
        _ rule: Rule,
        eventType: TriggerType,
        matchCondition: (Condition) -> Bool
    ) -> Bool {
        var conditions = rule.conditions
        guard !conditions.isEmpty else { return false }

        for i in conditions.indices {
            if matchCondition(conditions[i]) { conditions[i].isMet = true }
        }

        switch rule.conditionLogic {
        case .and:
            return conditions.allSatisfy { $0.isMet || isConditionCurrentlyMet($0) }
        case .or:
            return conditions.contains { matchCondition($0) }
        }
    }

    /// Live-state check for AND rules where co-conditions must also be satisfied.
    private func isConditionCurrentlyMet(_ condition: Condition) -> Bool {
        switch condition.type {
        case .wifiConnect:
            // Read SSID synchronously at evaluation time — avoids timing race with NWPathMonitor
            let ssid = WiFiMonitorService.currentSSIDSync()
            let connected = ssid != nil || wifi.isConnectedToWiFi
            if let configured = condition.config.wifiSSID { return connected && configured == ssid }
            return connected
        case .wifiDisconnect:
            let ssid = WiFiMonitorService.currentSSIDSync()
            let connected = ssid != nil || wifi.isConnectedToWiFi
            if let configured = condition.config.wifiSSID { return !connected || ssid != configured }
            return !connected
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
