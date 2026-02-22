import Foundation
import SwiftData
import CoreLocation

@MainActor
@Observable
final class PlacesViewModel {

    var places: [SavedPlace] = []
    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPlaces()
    }

    func loadPlaces() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<SavedPlace>(sortBy: [SortDescriptor(\.name)])
        places = (try? context.fetch(descriptor)) ?? []
    }

    func addPlace(name: String, coordinate: CLLocationCoordinate2D, radius: Double = 100, emoji: String = "📍") {
        guard let context = modelContext else { return }
        let place = SavedPlace(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            emoji: emoji
        )
        context.insert(place)
        try? context.save()
        loadPlaces()
    }

    func delete(place: SavedPlace) {
        LocationService.shared.stopMonitoring(place: place)
        modelContext?.delete(place)
        try? modelContext?.save()
        loadPlaces()
    }

    func deletePlaces(at offsets: IndexSet) {
        let placesToDelete = offsets.map { places[$0] }
        for place in placesToDelete {
            delete(place: place)
        }
    }

    var isAtGeofenceCapacity: Bool {
        LocationService.shared.isAtCapacity
    }

    var monitoredRegionCount: Int {
        LocationService.shared.monitoredRegionCount
    }
}
