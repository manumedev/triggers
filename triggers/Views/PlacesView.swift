import SwiftUI
import SwiftData

struct PlacesView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlacesViewModel()
    @State private var showingMapPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.places.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No Saved Places")
                            .font(.title3.bold())
                        Text("Add places to use in location-based rules.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        if viewModel.isAtGeofenceCapacity {
                            Section {
                                Label("Approaching the 20 active geofence limit set by iOS.", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                        ForEach(viewModel.places) { place in
                            HStack(spacing: 12) {
                                Text(place.emoji).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name).font(.headline)
                                    Text(String(format: "%.4f, %.4f — radius %d m",
                                                place.latitude, place.longitude, Int(place.radius)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            viewModel.deletePlaces(at: offsets)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingMapPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isAtGeofenceCapacity)
                }
            }
            .sheet(isPresented: $showingMapPicker, onDismiss: {
                viewModel.loadPlaces()
            }) {
                MapPickerView { name, coordinate, radius, emoji in
                    viewModel.addPlace(name: name, coordinate: coordinate, radius: radius, emoji: emoji)
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }
}
