import Foundation

enum RepeatBehavior: Codable, Equatable, Hashable {
    case once
    case always
    case cooldown(minutes: Int)

    var displayName: String {
        switch self {
        case .once:                    return "Once"
        case .always:                  return "Every time"
        case .cooldown(let mins):      return "At most once every \(mins) min"
        }
    }

    // MARK: - Manual Codable (associated values)
    private enum CodingKeys: String, CodingKey { case type, minutes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "once":     self = .once
        case "always":   self = .always
        case "cooldown":
            let mins = try c.decode(Int.self, forKey: .minutes)
            self = .cooldown(minutes: mins)
        default:         self = .always
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .once:
            try c.encode("once", forKey: .type)
        case .always:
            try c.encode("always", forKey: .type)
        case .cooldown(let mins):
            try c.encode("cooldown", forKey: .type)
            try c.encode(mins, forKey: .minutes)
        }
    }
}
