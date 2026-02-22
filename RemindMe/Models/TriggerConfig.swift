import Foundation

/// Flat Codable configuration for any trigger type.
/// Fields are optional — only those relevant to the trigger type are populated.
struct TriggerConfig: Codable, Equatable {

    // MARK: - Location
    var placeId: UUID?          // SavedPlace identifier
    var placeName: String?      // Display name fallback

    // MARK: - Time of Day
    var timeHour: Int?          // 0–23
    var timeMinute: Int?        // 0–59
    /// Weekdays to fire on. 1 = Sunday … 7 = Saturday (matches Calendar.Component.weekday)
    var weekdays: [Int]?

    // MARK: - WiFi
    var wifiSSID: String?

    // MARK: - Battery
    /// 0.0–1.0 (e.g. 0.2 = 20%)
    var batteryThreshold: Float?

    // MARK: - Calendar
    var minutesBefore: Int?     // Default: 30
    var eventKeyword: String?   // Optional keyword filter on event title

    // MARK: - Weather
    var temperatureThresholdCelsius: Double?

    // MARK: - Bluetooth
    var bluetoothDeviceName: String?
    var bluetoothDeviceUUID: String?    // CBPeripheral identifier string

    // MARK: - Convenience inits

    static func location(placeId: UUID, placeName: String) -> TriggerConfig {
        TriggerConfig(placeId: placeId, placeName: placeName)
    }

    static func timeOfDay(hour: Int, minute: Int, weekdays: [Int] = [1,2,3,4,5,6,7]) -> TriggerConfig {
        TriggerConfig(timeHour: hour, timeMinute: minute, weekdays: weekdays)
    }

    static func wifi(ssid: String) -> TriggerConfig {
        TriggerConfig(wifiSSID: ssid)
    }

    static func battery(threshold: Float) -> TriggerConfig {
        TriggerConfig(batteryThreshold: threshold)
    }

    static func calendar(minutesBefore: Int = 30, keyword: String? = nil) -> TriggerConfig {
        TriggerConfig(minutesBefore: minutesBefore, eventKeyword: keyword)
    }

    static func temperature(celsius: Double) -> TriggerConfig {
        TriggerConfig(temperatureThresholdCelsius: celsius)
    }

    static func bluetooth(deviceName: String, uuid: String? = nil) -> TriggerConfig {
        TriggerConfig(bluetoothDeviceName: deviceName, bluetoothDeviceUUID: uuid)
    }

    /// Human-readable summary of this config
    func summary(for type: TriggerType) -> String {
        switch type {
        case .locationArrive:
            return "Arrive at \(placeName ?? "unknown place")"
        case .locationLeave:
            return "Leave \(placeName ?? "unknown place")"
        case .timeOfDay:
            let h = timeHour ?? 0
            let m = timeMinute ?? 0
            let time = String(format: "%02d:%02d", h, m)
            return "At \(time)"
        case .wifiConnect:
            return "Connect to \"\(wifiSSID ?? "")\""
        case .wifiDisconnect:
            return "Disconnect from \"\(wifiSSID ?? "")\""
        case .batteryBelow:
            let pct = Int((batteryThreshold ?? 0.2) * 100)
            return "Battery below \(pct)%"
        case .batteryFull:
            return "Battery fully charged"
        case .chargingPluggedIn:
            return "Device plugged in"
        case .chargingUnplugged:
            return "Device unplugged"
        case .calendarEventSoon:
            let mins = minutesBefore ?? 30
            let kw = eventKeyword.map { " with \"\($0)\"" } ?? ""
            return "\(mins) min before event\(kw)"
        case .motionStartDriving:  return "Started driving"
        case .motionStopDriving:   return "Stopped driving"
        case .motionStartWalking:  return "Started walking"
        case .motionStartWorkout:  return "Started workout"
        case .weatherRaining:      return "It's raining at your location"
        case .weatherTemperatureBelow:
            let t = temperatureThresholdCelsius ?? 10
            return "Temperature below \(Int(t))°C"
        case .weatherTemperatureAbove:
            let t = temperatureThresholdCelsius ?? 30
            return "Temperature above \(Int(t))°C"
        case .bluetoothConnect:
            return "Connect to \"\(bluetoothDeviceName ?? "")\""
        case .bluetoothDisconnect:
            return "Disconnect from \"\(bluetoothDeviceName ?? "")\""
        case .screenFirstUnlock:   return "First screen unlock of the day"
        case .focusModeEnter:      return "Focus mode enabled"
        case .focusModeExit:       return "Focus mode disabled"
        }
    }
}
