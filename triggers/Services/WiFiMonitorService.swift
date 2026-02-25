import Foundation
import Network
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "WiFiMonitorService")

private let kLastConnectedKey = "wifi_lastConnected"
private let kLastSSIDKey      = "wifi_lastSSID"

@MainActor
final class WiFiMonitorService: ObservableObject {

    static let shared = WiFiMonitorService()

    @Published var isConnectedToWiFi: Bool = false
    @Published var currentSSID: String? = nil

    /// Fires with (ssid?, isConnected).
    var onSSIDEvent: ((String?, Bool) -> Void)?

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "com.triggers.wifi", qos: .utility)

    private init() {
        FileLogger.shared.log("WiFiMonitorService init", category: "WiFi")
        startMonitoring()
    }

    // MARK: - NWPathMonitor

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Read SSID synchronously on the monitor queue — no async hop, no race condition.
            let connected = path.status == .satisfied
            let ssid = connected ? WiFiMonitorService.readSSID() : nil
            let msg = "NWPathMonitor: connected=\(connected) ssid=\(ssid ?? "nil")"
            FileLogger.shared.log(msg, category: "WiFi")
            Task { @MainActor [weak self] in
                self?.handleNetworkChange(connected: connected, ssid: ssid)
            }
        }
        monitor.start(queue: monitorQueue)
        FileLogger.shared.log("NWPathMonitor started", category: "WiFi")
    }

    // MARK: - State change handling

    private func handleNetworkChange(connected: Bool, ssid: String?) {
        let defaults = UserDefaults.standard
        let prevConnected = defaults.bool(forKey: kLastConnectedKey)
        let prevSSID      = defaults.string(forKey: kLastSSIDKey)

        let msg = "handleNetworkChange: connected=\(connected) ssid=\(ssid ?? "nil") | prev=\(prevConnected) ssid=\(prevSSID ?? "nil")"
        logger.info("\(msg)")
        FileLogger.shared.log(msg, category: "WiFi")

        // Deduplication: same state as before → no change
        guard connected != prevConnected || ssid != prevSSID else {
            FileLogger.shared.log("  Duplicate — ignoring", category: "WiFi")
            return
        }

        // Persist and publish new state
        defaults.set(connected, forKey: kLastConnectedKey)
        defaults.set(ssid, forKey: kLastSSIDKey)
        isConnectedToWiFi = connected
        currentSSID = ssid

        fireEvents(connected: connected, ssid: ssid, prevConnected: prevConnected, prevSSID: prevSSID)
    }

    private func fireEvents(connected: Bool, ssid: String?, prevConnected: Bool, prevSSID: String?) {
        if connected {
            // Switched from one SSID to another → fire disconnect for the old one first
            if prevConnected, let oldSSID = prevSSID, oldSSID != ssid {
                let evt = "WiFi disconnect (switched away from '\(oldSSID)')"
                logger.info("\(evt)"); FileLogger.shared.log(evt, category: "WiFi")
                onSSIDEvent?(oldSSID, false)
            }
            let evt = "WiFi connect → '\(ssid ?? "any")'"
            logger.info("\(evt)"); FileLogger.shared.log(evt, category: "WiFi")
            onSSIDEvent?(ssid, true)
        } else if prevConnected {
            let evt = "WiFi disconnect (WiFi off, was '\(prevSSID ?? "any")')"
            logger.info("\(evt)"); FileLogger.shared.log(evt, category: "WiFi")
            onSSIDEvent?(prevSSID, false)
        }
    }

    // MARK: - Poll on wakeup

    /// Call on every app wakeup (becomeActive, background fetch) to catch changes
    /// that occurred while the app was suspended and NWPathMonitor wasn't running.
    func checkAndFireIfChanged() {
        let connected = WiFiMonitorService.readSSID() != nil || isWiFiReachable()
        let ssid = connected ? WiFiMonitorService.readSSID() : nil
        FileLogger.shared.log("checkAndFireIfChanged: connected=\(connected) ssid=\(ssid ?? "nil")", category: "WiFi")
        handleNetworkChange(connected: connected, ssid: ssid)
    }

    private func isWiFiReachable() -> Bool {
        // Fast reachability check without SSID requirement
        var address = sockaddr_in()
        address.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        guard let reachability = withUnsafePointer(to: &address, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return false }
        var flags: SCNetworkReachabilityFlags = []
        SCNetworkReachabilityGetFlags(reachability, &flags)
        return flags.contains(.reachable) && !flags.contains(.isWWAN)
    }

    // MARK: - Synchronous SSID read

    /// Reads the current WiFi SSID synchronously.
    /// Requires `com.apple.developer.networking.wifi-info` entitlement + location authorization.
    /// Returns nil if not connected or if entitlement/auth is missing.
    nonisolated static func readSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for iface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(iface as CFString) as? [String: Any],
               let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }
        return nil
    }

    /// Alias kept for callers that used the old name.
    nonisolated static func currentSSIDSync() -> String? { readSSID() }
}
