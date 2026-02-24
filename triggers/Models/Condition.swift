import Foundation

/// A single condition inside a Rule, linking a TriggerType to its configuration.
struct Condition: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: TriggerType
    var config: TriggerConfig

    /// Runtime-only: whether this condition is currently satisfied.
    /// Not persisted — evaluated fresh by RuleEvaluationEngine.
    var isMet: Bool = false

    var summary: String {
        config.summary(for: type)
    }

    // MARK: - Codable (exclude runtime `isMet`)
    private enum CodingKeys: String, CodingKey { case id, type, config }
}
