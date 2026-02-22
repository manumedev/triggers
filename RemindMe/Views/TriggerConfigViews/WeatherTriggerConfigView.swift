import SwiftUI

struct WeatherTriggerConfigView: View {

    let type: TriggerType
    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var temperature: Double = 10

    private var defaultTemp: Double {
        type == .weatherTemperatureAbove ? 30 : 10
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fire when temperature is \(type == .weatherTemperatureBelow ? "below" : "above") \(Int(temperature))°C")
                        .font(.subheadline)
                    Slider(value: $temperature, in: -20...45, step: 1) {
                        Text("Temperature")
                    } minimumValueLabel: {
                        Text("-20°").font(.caption)
                    } maximumValueLabel: {
                        Text("45°").font(.caption)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Temperature Threshold")
            } footer: {
                Text("Uses Apple WeatherKit to check weather at your current location. Requires an internet connection.")
            }
        }
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { temperature = defaultTemp }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    config.temperatureThresholdCelsius = temperature
                    onAdd()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
