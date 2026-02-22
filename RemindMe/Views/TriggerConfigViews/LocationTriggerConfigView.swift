import SwiftUI
import SwiftData
import MapKit

struct LocationTriggerConfigView: View {

    let type: TriggerType
    @Binding var config: TriggerConfig
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var places: [SavedPlace] = []
    @State private var selectedPlaceId: UUID? = nil
    @State private var showingMapPicker = false

    var body: some View {
        Form {
            Section("Select a Saved Place") {
                if places.isEmpty {
                    Text("No saved places yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(places) { place in
                    placeRow(place: place)
                }
                .onDelete { offsets in
                    deletePlace(at: offsets)
                }
                Button {
                    showingMapPicker = true
                } label: {
                    Label("Add New Place", systemImage: "plus")
                }
            }

            if let placeId = config.placeId,
               let place = places.first(where: { $0.id == placeId }) {
                Section("Radius") {
                    Text("Using place's saved radius: \(Int(place.radius)) m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(type == .locationArrive ? "Arrive at Place" : "Leave Place")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") { onAdd() }
                    .fontWeight(.semibold)
                    .disabled(selectedPlaceId == nil)
            }
        }
        .sheet(isPresented: $showingMapPicker) {
            MapPickerView { name, coordinate, radius, emoji in
                let place = SavedPlace(name: name, latitude: coordinate.latitude,
                                      longitude: coordinate.longitude, radius: radius, emoji: emoji)
                modelContext.insert(place)
                try? modelContext.save()
                loadPlaces()
                selectedPlaceId = place.id
                config.placeId = place.id
                config.placeName = place.name
            }
        }
        .onAppear { loadPlaces() }
    }

    private func loadPlaces() {
        let descriptor = FetchDescriptor<SavedPlace>(sortBy: [SortDescriptor(\.name)])
        places = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deletePlace(at offsets: IndexSet) {
        for index in offsets {
            let place = places[index]
            LocationService.shared.stopMonitoring(place: place)
            if config.placeId == place.id {
                config.placeId = nil
                config.placeName = nil
                selectedPlaceId = nil
            }
            modelContext.delete(place)
        }
        try? modelContext.save()
        loadPlaces()
    }

    @ViewBuilder
    private func placeRow(place: SavedPlace) -> some View {
        HStack {
            Text(place.emoji)
            Text(place.name)
            Spacer()
            if selectedPlaceId == place.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPlaceId = place.id
            config.placeId = place.id
            config.placeName = place.name
        }
    }
}
