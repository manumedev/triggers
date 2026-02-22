import SwiftUI

struct CalendarTriggerConfigView: View {

    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var minutesBefore: Double = 30
    @State private var keyword: String = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fire \(Int(minutesBefore)) minutes before event")
                        .font(.subheadline)
                    Slider(value: $minutesBefore, in: 5...120, step: 5) {
                        Text("Minutes")
                    } minimumValueLabel: {
                        Text("5").font(.caption)
                    } maximumValueLabel: {
                        Text("120").font(.caption)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Time Before Event")
            }

            Section {
                TextField("Keyword (optional)", text: $keyword)
                    .autocorrectionDisabled()
            } header: {
                Text("Event Title Filter")
            } footer: {
                Text("If set, only fires for events whose title contains this keyword (e.g. \"Flight\", \"Doctor\").")
            }
        }
        .navigationTitle("Calendar Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    config.minutesBefore = Int(minutesBefore)
                    config.eventKeyword = keyword.trimmingCharacters(in: .whitespaces).isEmpty ? nil : keyword
                    onAdd()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
