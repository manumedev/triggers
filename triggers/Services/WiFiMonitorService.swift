import Foundation
import Network
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "WiFiMonitorService")

private let kLastConnectedKey = "wifi_lastConnected"
private let kLastSSIDKey = "wifi_lastSSID"
private let kHasLaunchedKey = "wifi_hasLaunched"

@MainActor
final class WiFiMonitorService: ObservableObject {

    static let shared = WiFiMonitorService()

    @Published var isConnectedToWiFi: Bool = false
    @Published var currentSSID: String? = nil

    /// Fires with (ssid?, isConnected).
    var onSSIDEvent: ((String?, Bool) -> Void)?

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "com.triggers.wifi", qos: .utility)

    // In-memory SSID state for deduplication within a session
    private var sessionSSID: String? = nil
    private var sessionConnected: Bool = false
    private var baselineRecorded: Bool = false

    private init() {
        FileLogger.shared.log("WiFiMonitorService init", category: "WiFi")
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            FileLogger.shared.log("NWPathMonitor: connected=\(connected)", category: "WiFi")

            if connected {
                // Fetch SSID immediately — no debounce so we capture the current network
                // before it potentially switches back. Deduplication is SSID-based, not time-based.
                NEHotspotNetwork.fetchCurrent { [weak self] network in
                    let ssid = network?.ssid
                    FileLogger.shared.log("NEHotspot callback: ssid=\(ssid ?? "nil")", category: "WiFi")
                    Task { @MainActor [weak self] in
                        self?.handleNetworkChange(connected: true, ssid: ssid)
                    }
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleNetworkChange(connected: false, ssid: nil)
                }
            }
        }
        monitor.start(queue: monitorQueue)
        FileLogger.shared.log("NWPathMonitor started", category: "WiFi")
    }

    private func handleNetworkChange(connected: Bool, ssid: String?) {
        if connected && ssid == nil {
            if baselineRecorded {
                // Active session: nil SSID is transient during handoff — skip
                FileLogger.shared.log("Skipping transient nil-SSID (active session)", category: "WiFi")
            } else {
                // Startup: SSID not ready yet — retry after 1.5s so we catch the real SSID
                // before the app potentially goes back to sleep
                FileLogger.shared.log("Startup nil-SSID — scheduling retry in 1.5s", category: "WiFi")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, !self.baselineRecorded else { return }
                    NEHotspotNetwork.fetchCurrent { [weak self] network in
                        let ssid = network?.ssid
                        FileLogger.shared.log("Startup retry SSID=\(ssid ?? "nil")", category: "WiFi")
                        Task { @MainActor [weak self] in
                            self?.handleNetworkChange(connected: true, ssid: ssid)
                        }
                    }
                }
            }
            return
        }

        let defaults = UserDefaults.standard
        let persistedConnected = defaults.bool(forKey: kLastConnectedKey)
        let persistedSSID = defaults.string(forKey: kLastSSIDKey)

        // Use in-memory state if available (same session), otherwise fall back to persisted
        let prevConnected = baselineRecorded ? sessionConnected : persistedConnected
        let prevSSID     = baselineRecorded ? sessionSSID      : persistedSSID

        let msg = "handleNetworkChange: connected=\(connected) ssid=\(ssid ?? "nil") | prev=\(prevConnected) ssid=\(prevSSID ?? "nil") baseline=\(baselineRecorded)"
        logger.info("\(msg)")
        FileLogger.shared.log(msg, category: "WiFi")

        // Deduplication: same state as before → ignore
        if connected == prevConnected && ssid == prevSSID {
            FileLogger.shared.log("  Duplicate — ignoring", category: "WiFi")
            return
        }

        // Update in-memory and persisted state
        baselineRecorded = true
        sessionConnected = connected
        sessionSSID = ssid
        defaults.set(true, forKey: kHasLaunchedKey)
        defaults.set(connected, forKey: kLastConnectedKey)
        defaults.set(ssid, forKey: kLastSSIDKey)

        isConnectedToWiFi = connected
        currentSSID = ssid

        let hasLaunched = defaults.bool(forKey: kHasLaunchedKey)

        // First-ever app launch: just record baseline, don't fire
        guard hasLaunched else {
            FileLogger.shared.log("  First-launch baseline recorded", category: "WiFi")
            return
        }

        if connected {
            // Switched from one network to another
            if prevConnected, let oldSSID = prevSSID, oldSSID != ssid {
                let evt = "WiFi disconnect (switched away from '\(oldSSID)')"
                logger.info("\(evt)")
                FileLogger.shared.log(evt, category: "WiFi")
                onSSIDEvent?(oldSSID, false)
            } else if !prevConnected {
                // Was disconnected, now connected (first connect or reconnect)
            }
            let evt = "WiFi connect → '\(ssid ?? "nil")'"
            logger.info("\(evt)")
            FileLogger.shared.log(evt, category: "WiFi")
            onSSIDEvent?(ssid, true)
        } else if !connected && prevConnected {
            let evt = "WiFi disconnect (WiFi off, was '\(prevSSID ?? "nil")')"
            logger.info("\(evt)")
            FileLogger.shared.log(evt, category: "WiFi")
            onSSIDEvent?(prevSSID, false)
        }
    }

    /// Synchronous SSID read used for AND-rule co-condition checks in RuleEvaluationEngine.
    /// Must be called on the main thread.
    static func currentSSIDSync() -> String? {
        // NEHotspotNetwork.fetchCurrent is async-only; fall back to CNCopyCurrentNetworkInfo
        // which works synchronously on main thread with the wifi-info entitlement.
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
               let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }
        return nil
    }
}
