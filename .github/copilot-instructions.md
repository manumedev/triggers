# Triggers – Copilot Instructions

## Build

The project is managed with **XcodeGen**. Regenerate the `.xcodeproj` after editing `project.yml`:

```bash
xcodegen generate
```

Build from the command line:

```bash
xcodebuild -project triggers.xcodeproj -scheme Triggers -destination 'platform=iOS Simulator,name=iPhone 16' build
```

There are no automated tests in this project.

## Architecture

Triggers is an iOS 17+ app (Swift 6.0) that fires local notifications when user-defined rule conditions are met.

### Core data flow

1. **`Rule`** – a SwiftData `@Model` owned by `PersistenceService`. Holds an array of `Condition` objects and a `conditionLogic` (AND / OR). Complex fields (`conditions`, `repeatBehavior`) are stored as JSON-encoded `Data` because SwiftData doesn't support custom Codable enums or arrays of structs natively.
2. **`Condition`** – pairs a `TriggerType` (enum) with a flat `TriggerConfig` struct. All `TriggerConfig` fields are optional; only the fields relevant to the trigger type are populated.
3. **Sensor services** – each monitors one data source (location, WiFi, battery, calendar, motion, weather, Bluetooth, screen unlock, focus mode) and fires a callback when a relevant event occurs. All are `@MainActor` singletons.
4. **`RuleEvaluationEngine`** – wires callbacks from every service, then for each event fetches enabled rules and evaluates AND/OR condition logic using `evaluateRule(_:eventType:matchCondition:)`. Fires `NotificationService` when a rule passes.

### MVVM layer

- `@Observable` ViewModels (`RuleBuilderViewModel`, `RulesListViewModel`, `PlacesViewModel`) are `@MainActor` and own SwiftData `ModelContext`.
- Views inject `modelContext` into ViewModels via `.onAppear` / `setup(modelContext:)`.
- `RuleBuilderViewModel` handles both create and edit flows via `isEditing` + `load(rule:)`.

### Persistence

`PersistenceService.shared` returns a `ModelContainer` registered for `Rule` and `SavedPlace`. It is injected at the scene level via `.modelContainer(PersistenceService.shared)`.

## Key conventions

- **`TriggerConfig` is a flat optional bag** – don't add a per-trigger-type config type. Add a new optional field for each new trigger's parameters.
- **JSON encoding for SwiftData arrays/enums** – `Rule.conditions` is stored as `conditionsData: Data` (JSON). Similarly, `repeatBehaviorData: Data` stores `RepeatBehavior`. Always go through the computed property accessors, never touch `*Data` fields directly.
- **`RepeatBehavior` has manual `Codable`** – it uses an associated value (`cooldown(minutes: Int)`), so it implements `init(from:)` and `encode(to:)` by hand. Follow the same pattern for any new enums with associated values.
- **All sensor services use closure callbacks** – prefer `onXxxEvent: ((…) -> Void)?` properties rather than delegates or Combine. `RuleEvaluationEngine` is the only consumer.
- **Logger uses OSLog** – `Logger(subsystem: "com.triggers.app", category: "<ClassName>")` at file scope; use `logger.info/debug/error` (never `print`).
- **`TriggerType.category`** drives grouping in `TriggerPickerView`. When adding a new trigger type, update `displayName`, `systemImage`, and `category` on `TriggerType`, add a case to `TriggerConfig.summary(for:)`, and add a `TriggerConfigView` under `Views/TriggerConfigViews/`.
- **Geofences are registered via `LocationService.startMonitoring(place:)`** after saving a rule. `RuleBuilderViewModel.refreshGeofences(for:)` handles this after every save.
- **`isMet` on `Condition` is runtime-only** – it is excluded from `Codable` via `CodingKeys` and must never be persisted.
- **Swift 6 strict concurrency** – all new types that touch shared state must be `@MainActor` or `Sendable`. Services are `@MainActor final class`.
