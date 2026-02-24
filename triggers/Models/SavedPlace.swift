import Foundation
import SwiftData

@Model
final class SavedPlace {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    /// Geofence radius in metres (default 100 m)
    var radius: Double

    var emoji: String  // e.g. "🏠", "🏢", "🛒"

    init(name: String, latitude: Double, longitude: Double, radius: Double = 100, emoji: String = "📍") {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.emoji = emoji
    }
}
