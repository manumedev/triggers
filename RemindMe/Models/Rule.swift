import Foundation
import SwiftData

@Model
final class Rule: Identifiable {
    var id: UUID
    var name: String
    var notificationTitle: String
    var notificationBody: String
    var isEnabled: Bool

    /// Stored as JSON-encoded [Condition]
    var conditionsData: Data

    var conditionLogicRaw: String      // ConditionLogic.rawValue
    var repeatBehaviorData: Data       // JSON-encoded RepeatBehavior

    var createdAt: Date
    var lastFiredAt: Date?

    // MARK: - Computed helpers

    var conditionLogic: ConditionLogic {
        get { ConditionLogic(rawValue: conditionLogicRaw) ?? .and }
        set { conditionLogicRaw = newValue.rawValue }
    }

    var conditions: [Condition] {
        get { (try? JSONDecoder().decode([Condition].self, from: conditionsData)) ?? [] }
        set { conditionsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var repeatBehavior: RepeatBehavior {
        get { (try? JSONDecoder().decode(RepeatBehavior.self, from: repeatBehaviorData)) ?? .always }
        set { repeatBehaviorData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // MARK: - Init

    init(
        name: String = "New Rule",
        notificationTitle: String = "",
        notificationBody: String = "",
        isEnabled: Bool = true,
        conditions: [Condition] = [],
        conditionLogic: ConditionLogic = .and,
        repeatBehavior: RepeatBehavior = .always
    ) {
        self.id = UUID()
        self.name = name
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
        self.isEnabled = isEnabled
        self.conditionsData = (try? JSONEncoder().encode(conditions)) ?? Data()
        self.conditionLogicRaw = conditionLogic.rawValue
        self.repeatBehaviorData = (try? JSONEncoder().encode(repeatBehavior)) ?? Data()
        self.createdAt = Date()
        self.lastFiredAt = nil
    }

    /// Returns true if this rule can fire again based on its repeat behavior.
    func canFire() -> Bool {
        switch repeatBehavior {
        case .once:
            return lastFiredAt == nil
        case .always:
            return true
        case .cooldown(let minutes):
            guard let last = lastFiredAt else { return true }
            return Date().timeIntervalSince(last) >= Double(minutes) * 60
        }
    }
}
