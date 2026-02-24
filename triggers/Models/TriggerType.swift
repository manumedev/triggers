import Foundation

// All supported trigger types
enum TriggerType: String, Codable, CaseIterable, Identifiable {
    // Location
    case locationArrive = "location_arrive"
    case locationLeave  = "location_leave"

    // Time
    case timeOfDay = "time_of_day"

    // WiFi
    case wifiConnect    = "wifi_connect"
    case wifiDisconnect = "wifi_disconnect"

    // Battery
    case batteryBelow = "battery_below"
    case batteryFull  = "battery_full"

    // Charging
    case chargingPluggedIn  = "charging_plugged_in"
    case chargingUnplugged  = "charging_unplugged"

    // Calendar
    case calendarEventSoon = "calendar_event_soon"

    // Motion / Activity
    case motionStartDriving  = "motion_start_driving"
    case motionStopDriving   = "motion_stop_driving"
    case motionStartWalking  = "motion_start_walking"
    case motionStartWorkout  = "motion_start_workout"

    // Weather (WeatherKit)
    case weatherRaining          = "weather_raining"
    case weatherTemperatureBelow = "weather_temperature_below"
    case weatherTemperatureAbove = "weather_temperature_above"

    // Bluetooth
    case bluetoothConnect    = "bluetooth_connect"
    case bluetoothDisconnect = "bluetooth_disconnect"

    // Device / App state
    case screenFirstUnlock = "screen_first_unlock"
    case focusModeEnter    = "focus_mode_enter"
    case focusModeExit     = "focus_mode_exit"

    var id: String { rawValue }

    /// Whether this trigger is currently implemented and available to users.
    /// Others are preserved in the model for future implementation.
    var isAvailable: Bool {
        switch self {
        case .locationArrive, .locationLeave, .wifiConnect, .wifiDisconnect,
             .bluetoothConnect, .bluetoothDisconnect:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .locationArrive:          return "Arrive at Place"
        case .locationLeave:           return "Leave Place"
        case .timeOfDay:               return "Time of Day"
        case .wifiConnect:             return "Connect to WiFi"
        case .wifiDisconnect:          return "Disconnect from WiFi"
        case .batteryBelow:            return "Battery Low"
        case .batteryFull:             return "Battery Full"
        case .chargingPluggedIn:       return "Plugged In"
        case .chargingUnplugged:       return "Unplugged"
        case .calendarEventSoon:       return "Calendar Event Soon"
        case .motionStartDriving:      return "Start Driving"
        case .motionStopDriving:       return "Stop Driving"
        case .motionStartWalking:      return "Start Walking"
        case .motionStartWorkout:      return "Start Workout"
        case .weatherRaining:          return "It's Raining"
        case .weatherTemperatureBelow: return "Temperature Below"
        case .weatherTemperatureAbove: return "Temperature Above"
        case .bluetoothConnect:        return "Bluetooth Device Connected"
        case .bluetoothDisconnect:     return "Bluetooth Device Disconnected"
        case .screenFirstUnlock:       return "First Screen Unlock of Day"
        case .focusModeEnter:          return "Focus Mode Enabled"
        case .focusModeExit:           return "Focus Mode Disabled"
        }
    }

    var systemImage: String {
        switch self {
        case .locationArrive, .locationLeave:                return "location.fill"
        case .timeOfDay:                                      return "clock.fill"
        case .wifiConnect, .wifiDisconnect:                  return "wifi"
        case .batteryBelow, .batteryFull:                    return "battery.50percent"
        case .chargingPluggedIn, .chargingUnplugged:         return "bolt.fill"
        case .calendarEventSoon:                             return "calendar"
        case .motionStartDriving, .motionStopDriving:        return "car.fill"
        case .motionStartWalking:                            return "figure.walk"
        case .motionStartWorkout:                            return "dumbbell.fill"
        case .weatherRaining:                                return "cloud.rain.fill"
        case .weatherTemperatureBelow, .weatherTemperatureAbove: return "thermometer.medium"
        case .bluetoothConnect, .bluetoothDisconnect:        return "bluetooth"
        case .screenFirstUnlock:                             return "lock.open.fill"
        case .focusModeEnter, .focusModeExit:               return "moon.fill"
        }
    }

    var category: String {
        switch self {
        case .locationArrive, .locationLeave:                return "Location"
        case .timeOfDay:                                      return "Time"
        case .wifiConnect, .wifiDisconnect:                  return "Network"
        case .batteryBelow, .batteryFull,
             .chargingPluggedIn, .chargingUnplugged:         return "Device"
        case .calendarEventSoon:                             return "Calendar"
        case .motionStartDriving, .motionStopDriving,
             .motionStartWalking, .motionStartWorkout:       return "Activity"
        case .weatherRaining, .weatherTemperatureBelow,
             .weatherTemperatureAbove:                       return "Weather"
        case .bluetoothConnect, .bluetoothDisconnect:        return "Bluetooth"
        case .screenFirstUnlock, .focusModeEnter,
             .focusModeExit:                                 return "System"
        }
    }
}
