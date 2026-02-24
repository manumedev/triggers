import SwiftUI

struct TriggerPickerView: View {

    let onSelect: (Condition) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: TriggerType? = nil
    @State private var config = TriggerConfig()

    private var groupedTypes: [String: [TriggerType]] {
        Dictionary(grouping: TriggerType.allCases.filter(\.isAvailable), by: { $0.category })
    }

    private var sortedCategories: [String] {
        ["Location", "Network"]
    }

    var body: some View {
        NavigationStack {
            if let type = selectedType {
                configView(for: type)
            } else {
                typePickerList
            }
        }
    }

    // MARK: - Type picker

    private var typePickerList: some View {
        List {
            ForEach(sortedCategories, id: \.self) { category in
                self.categorySection(category: category)
            }
        }
        .navigationTitle("Choose Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func categorySection(category: String) -> some View {
        if let types = groupedTypes[category] {
            Section(category) {
                ForEach(types) { type in
                    Button {
                        config = TriggerConfig()
                        selectedType = type
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: type.systemImage)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 30)
                            Text(type.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Config view routing

    @ViewBuilder
    private func configView(for type: TriggerType) -> some View {
        switch type {
        case .locationArrive, .locationLeave:
            LocationTriggerConfigView(type: type, config: $config) { add() }
        case .timeOfDay:
            TimeTriggerConfigView(config: $config) { add() }
        case .wifiConnect, .wifiDisconnect:
            WiFiTriggerConfigView(type: type, config: $config) { add() }
        case .batteryBelow:
            BatteryTriggerConfigView(config: $config) { add() }
        case .batteryFull, .chargingPluggedIn, .chargingUnplugged,
             .screenFirstUnlock, .focusModeEnter, .focusModeExit,
             .motionStartDriving, .motionStopDriving, .motionStartWalking,
             .motionStartWorkout:
            SimpleConfirmView(type: type) { add() }
        case .calendarEventSoon:
            CalendarTriggerConfigView(config: $config) { add() }
        case .weatherRaining:
            SimpleConfirmView(type: type) { add() }
        case .weatherTemperatureBelow, .weatherTemperatureAbove:
            WeatherTriggerConfigView(type: type, config: $config) { add() }
        case .bluetoothConnect, .bluetoothDisconnect:
            BluetoothTriggerConfigView(type: type, config: $config) { add() }
        }
    }

    private func add() {
        guard let type = selectedType else { return }
        let condition = Condition(type: type, config: config)
        onSelect(condition)
        dismiss()
    }
}

// MARK: - Simple confirm (no extra config needed)

private struct SimpleConfirmView: View {
    let type: TriggerType
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: type.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading) {
                        Text(type.displayName).font(.headline)
                        Text("No extra configuration needed.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Add Condition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") { onAdd() }.fontWeight(.semibold)
            }
        }
    }
}
