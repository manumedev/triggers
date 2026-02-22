import Foundation
import SwiftData

@MainActor
@Observable
final class RuleBuilderViewModel {

    var name: String = "New Rule"
    var notificationTitle: String = ""
    var notificationBody: String = ""
    var conditionLogic: ConditionLogic = .and
    var repeatBehavior: RepeatBehavior = .always
    var conditions: [Condition] = []

    var isEditing: Bool = false
    private var editingRule: Rule?
    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(rule: Rule) {
        isEditing = true
        editingRule = rule
        name = rule.name
        notificationTitle = rule.notificationTitle
        notificationBody = rule.notificationBody
        conditionLogic = rule.conditionLogic
        repeatBehavior = rule.repeatBehavior
        conditions = rule.conditions
    }

    func reset() {
        isEditing = false
        editingRule = nil
        name = "New Rule"
        notificationTitle = ""
        notificationBody = ""
        conditionLogic = .and
        repeatBehavior = .always
        conditions = []
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !notificationBody.trimmingCharacters(in: .whitespaces).isEmpty &&
        !conditions.isEmpty
    }

    func addCondition(_ condition: Condition) {
        conditions.append(condition)
    }

    func removeCondition(at offsets: IndexSet) {
        conditions.remove(atOffsets: offsets)
    }

    func moveCondition(from source: IndexSet, to destination: Int) {
        conditions.move(fromOffsets: source, toOffset: destination)
    }

    @discardableResult
    func save() -> Rule? {
        guard let context = modelContext else { return nil }

        if isEditing, let rule = editingRule {
            // Stop geofences for location conditions that were removed during edit
            let oldPlaceIds = Set(rule.conditions.compactMap { $0.config.placeId })
            let newPlaceIds = Set(conditions.compactMap { $0.config.placeId })
            let removedPlaceIds = oldPlaceIds.subtracting(newPlaceIds)
            for placeId in removedPlaceIds {
                let descriptor = FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.id == placeId })
                if let place = try? context.fetch(descriptor).first {
                    LocationService.shared.stopMonitoring(place: place)
                }
            }

            rule.name = name
            rule.notificationTitle = notificationTitle
            rule.notificationBody = notificationBody
            rule.conditionLogic = conditionLogic
            rule.repeatBehavior = repeatBehavior
            rule.conditions = conditions
            try? context.save()
            refreshGeofences(for: rule)
            return rule
        } else {
            let rule = Rule(
                name: name,
                notificationTitle: notificationTitle.isEmpty ? name : notificationTitle,
                notificationBody: notificationBody,
                isEnabled: true,
                conditions: conditions,
                conditionLogic: conditionLogic,
                repeatBehavior: repeatBehavior
            )
            context.insert(rule)
            try? context.save()
            refreshGeofences(for: rule)
            return rule
        }
    }

    private func refreshGeofences(for rule: Rule) {
        guard let context = modelContext else { return }
        let location = LocationService.shared
        for condition in rule.conditions {
            guard let placeId = condition.config.placeId else { continue }
            let descriptor = FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.id == placeId })
            if let place = try? context.fetch(descriptor).first {
                if rule.isEnabled {
                    location.startMonitoring(place: place)
                } else {
                    location.stopMonitoring(place: place)
                }
            }
        }
    }
}
