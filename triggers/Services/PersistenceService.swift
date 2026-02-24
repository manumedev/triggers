import Foundation
import SwiftData

/// Central persistence container. Inject into the environment via `.modelContainer`.
@MainActor
final class PersistenceService {

    static let shared: ModelContainer = {
        let schema = Schema([Rule.self, SavedPlace.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }()
}
