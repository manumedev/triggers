import Foundation

enum ConditionLogic: String, Codable, CaseIterable {
    case and = "and"
    case or  = "or"

    var displayName: String {
        switch self {
        case .and: return "AND"
        case .or:  return "OR"
        }
    }

    var description: String {
        switch self {
        case .and: return "All conditions must be true"
        case .or:  return "Any condition being true is enough"
        }
    }
}
