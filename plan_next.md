# RemindMe — Next Trigger Types to Implement

WiFi and Location are live. Each section below is one self-contained implementation sprint.
Add `isAvailable: Bool { return true }` to the trigger cases in `TriggerType.swift` when done.

---

## 1. Bluetooth — Connect / Disconnect
**Triggers:** `bluetoothConnect`, `bluetoothDisconnect`

- `BluetoothService` already exists (CBCentralManager, delegate, `onDeviceEvent` callback)
- Wire `bluetooth.onDeviceEvent` in `RuleEvaluationEngine.wireCallbacks()`
- Add `evaluateBluetooth(deviceName:triggerType:)` — match on `cond.config.bluetoothDeviceName`
- `BluetoothTriggerConfigView` already exists
- Enable `isAvailable` for both cases

---

## 2. Battery — Low / Full / Plugged In / Unplugged
**Triggers:** `batteryBelow`, `batteryFull`, `chargingPluggedIn`, `chargingUnplugged`

- `BatteryMonitorService` already exists (`UIDevice` battery notifications)
- Wire `battery.onBatteryEvent` in engine
- State-change based: track `prevIsCharging`, `prevIsFull`, `prevBatteryLevel`
  - `batteryBelow`: fires only when level crosses threshold downward
  - `batteryFull`: fires only on `.full` transition
  - `chargingPluggedIn`: fires only on `false → true` charging transition
  - `chargingUnplugged`: fires only on `true → false` charging transition
- `BatteryTriggerConfigView` already exists (for `batteryBelow` threshold)
- `SimpleConfirmView` for the other three
- `isConditionCurrentlyMet`: add battery/charging live-state checks for AND logic

---

## 3. Motion — Driving / Walking / Workout
**Triggers:** `motionStartDriving`, `motionStopDriving`, `motionStartWalking`, `motionStartWorkout`

- `MotionService` already exists (CMMotionActivityManager, `activityQueue`, `@Sendable` fix applied)
- **Critical fix already landed:** `@Sendable` on the callback closure prevents `@MainActor` inference crash
- Wire `motion.onActivityChanged` in engine, call `motion.startMonitoring()` in `engine.start()`
- State-change based: track `prevMotionActivity`
  - `motionStartDriving`: fires only on transition TO `.automotive`
  - `motionStopDriving`: fires only on transition FROM `.automotive` to `.stationary`
  - `motionStartWalking`: fires only on transition TO `.walking`
  - `motionStartWorkout`: fires only on transition TO `.running` or `.cycling`
- All use `SimpleConfirmView`
- `isConditionCurrentlyMet`: add motion live-state checks for AND logic

---

## 4. Weather — Rain / Temperature
**Triggers:** `weatherRaining`, `weatherTemperatureBelow`, `weatherTemperatureAbove`

- `WeatherService` already exists (WeatherKit, `fetchWeather(for:)`)
- Piggyback weather fetch on location events (already scaffolded)
- Wire `weather.onWeatherUpdated` in engine
- State-change based: track `prevIsRaining`, `prevTemperatureCelsius`
  - `weatherRaining`: fires only on `false → true` rain transition
  - Temperature: fires only when crossing the configured threshold
- `WeatherTriggerConfigView` already exists
- Requires WeatherKit entitlement to be active in provisioning profile

---

## 5. Calendar — Upcoming Event
**Trigger:** `calendarEventSoon`

- `CalendarService` already exists (EKEventStore, polling timer, `onUpcomingEvent` callback)
- Wire `calendar.onUpcomingEvent` in engine, call `calendar.startPolling()` in `engine.start()`
- Match on `cond.config.minutesBefore` and optional `cond.config.eventKeyword`
- Requires `NSCalendarsFullAccessUsageDescription` in Info.plist
- `CalendarTriggerConfigView` already exists

---

## 6. Screen Unlock — First of Day
**Trigger:** `screenFirstUnlock`

- `ScreenUnlockService` already exists (`UIApplication.protectedDataDidBecomeAvailableNotification`)
- Wire `screen.onFirstUnlockOfDay` in engine
- Stateless event (fires once per day on first unlock)
- Uses `SimpleConfirmView`

---

## 7. Focus Mode — Enter / Exit
**Trigger:** `focusModeEnter`, `focusModeExit`

- `FocusModeService` already exists (polls `UNUserNotificationCenter.notificationSettings`)
- Wire `focus.onFocusEnter` / `focus.onFocusExit` in engine
- State-change based (FocusModeService already tracks `isFocusActive`)
- Uses `SimpleConfirmView`

---

## 8. Time of Day
**Trigger:** `timeOfDay`

- Not yet implemented — needs a new `TimeService` (background timer or `UNCalendarNotificationTrigger`)
- `TimeTriggerConfigView` already exists (time picker UI)
- Wire up a scheduler that fires the event at the configured time daily

---

## Notes

- All services already exist as files — re-enabling a trigger mostly means wiring its callback in `RuleEvaluationEngine` and setting `isAvailable = true` in `TriggerType`
- Each trigger should be tested on device before moving to the next (background delivery requires real hardware)
- For state-change triggers: restore `snapshotCurrentState()` call in `engine.start()` and `RuleBuilderViewModel.save()` when those services are re-enabled
