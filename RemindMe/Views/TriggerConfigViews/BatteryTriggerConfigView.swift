import SwiftUI

struct BatteryTriggerConfigView: View {

    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var threshold: Double = 20

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fire when battery drops below \(Int(threshold))%")
                        .font(.subheadline)
                    Slider(value: $threshold, in: 5...50, step: 5) {
                        Text("Threshold")
                    } minimumValueLabel: {
                        Text("5%").font(.caption)
                    } maximumValueLabel: {
                        Text("50%").font(.caption)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Battery Threshold")
            } footer: {
                Text("A notification fires once when the battery drops to this level.")
            }
        }
        .navigationTitle("Battery Low")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    config.batteryThreshold = Float(threshold / 100)
                    onAdd()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
