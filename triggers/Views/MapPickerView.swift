import SwiftUI
@preconcurrency import MapKit
import CoreLocation

final class PlaceSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate, @unchecked Sendable {
    @Published var results: [MKLocalSearchCompletion] = []
    let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        DispatchQueue.main.async { self.results = results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.results = [] }
    }
}

struct MapPickerView: View {

    let onSave: (String, CLLocationCoordinate2D, Double, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var pickedCoordinate: CLLocationCoordinate2D? = nil
    @State private var placeName: String = ""
    @State private var radius: Double = 100
    @State private var emoji: String = "📍"
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @StateObject private var searchCompleter = PlaceSearchCompleter()

    private let emojiOptions = ["📍", "🏠", "🏢", "🛒", "🏋️", "🏥", "⛽️", "🍔", "🏫", "✈️", "🚗"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search for a place…", text: $searchText)
                        .autocorrectionDisabled()
                        .onTapGesture { isSearching = true }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                isSearching = false
                                searchCompleter.results = []
                            } else {
                                isSearching = true
                                searchCompleter.search(query: newValue)
                            }
                        }
                    if !searchText.isEmpty {
                        Button { searchText = ""; isSearching = false; searchCompleter.results = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 8)

                if isSearching && !searchCompleter.results.isEmpty {
                    // Search suggestions overlay
                    List(searchCompleter.results, id: \.self) { result in
                        Button {
                            selectSearchResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title).foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                } else {
                    // Map
                    Map(position: $position) {
                        if let coord = pickedCoordinate {
                            Annotation(placeName.isEmpty ? "Picked Location" : placeName, coordinate: coord) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
                    .ignoresSafeArea(.keyboard)

                    // Form
                    Form {
                        Section("Place Details") {
                            TextField("Name (e.g. Home, Office)", text: $placeName)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(emojiOptions, id: \.self) { e in
                                        Button {
                                            emoji = e
                                        } label: {
                                            Text(e)
                                                .font(.title2)
                                                .padding(6)
                                                .background(emoji == e ? Color.accentColor.opacity(0.2) : Color.clear)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Radius: \(Int(radius)) m")
                                Slider(value: $radius, in: 100...500, step: 25)
                            }
                        } header: {
                            Text("Geofence Radius")
                        } footer: {
                            Text("The area around the location that triggers the reminder.")
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let coord = pickedCoordinate ?? position.region?.center ?? CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312)
                        onSave(placeName.isEmpty ? "My Place" : placeName, coord, radius, emoji)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: result)
        Task {
            if let response = try? await MKLocalSearch(request: request).start(),
               let item = response.mapItems.first {
                let coord = item.placemark.coordinate
                pickedCoordinate = coord
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
                if placeName.isEmpty {
                    placeName = result.title
                }
            }
            searchText = result.title
            isSearching = false
            searchCompleter.results = []
        }
    }
}
