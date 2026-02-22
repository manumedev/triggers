import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "RulesListViewModel")

@MainActor
@Observable
final class RulesListViewModel {

    var rules: [Rule] = []
    var searchText: String = ""

    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRules()
    }

    func loadRules() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Rule>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        rules = (try? context.fetch(descriptor)) ?? []
    }

    var filteredRules: [Rule] {
        guard !searchText.isEmpty else { return rules }
        return rules.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func toggle(rule: Rule) {
        rule.isEnabled.toggle()
        try? modelContext?.save()
        // Re-register or un-register geofences as needed
        let location = LocationService.shared
        for condition in rule.conditions {
            guard let placeId = condition.config.placeId else { continue }
            if rule.isEnabled {
                if let place = fetchPlace(id: placeId) {
                    location.startMonitoring(place: place)
                }
            } else {
                if let place = fetchPlace(id: placeId) {
                    location.stopMonitoring(place: place)
                }
            }
        }
    }

    func delete(rule: Rule) {
        // Stop geofence monitoring for this rule's location conditions
        for condition in rule.conditions {
            if let placeId = condition.config.placeId,
               let place = fetchPlace(id: placeId) {
                LocationService.shared.stopMonitoring(place: place)
            }
        }
        modelContext?.delete(rule)
        try? modelContext?.save()
        loadRules()
    }

    func deleteRules(at offsets: IndexSet) {
        let rulesToDelete = offsets.map { filteredRules[$0] }
        for rule in rulesToDelete {
            delete(rule: rule)
        }
    }

    private func fetchPlace(id: UUID) -> SavedPlace? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
