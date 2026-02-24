import SwiftUI

struct TimeTriggerConfigView: View {

    @Binding var config: TriggerConfig
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8; components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    @State private var selectedWeekdays: Set<Int> = Set(1...7)  // All days by default

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        Form {
            Section("Time") {
                DatePicker("Fire at", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Section("Days") {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        let isSelected = selectedWeekdays.contains(day)
                        Button {
                            if isSelected {
                                if selectedWeekdays.count > 1 {
                                    selectedWeekdays.remove(day)
                                }
                            } else {
                                selectedWeekdays.insert(day)
                            }
                        } label: {
                            Text(weekdayNames[day - 1])
                                .font(.caption.bold())
                                .frame(width: 38, height: 38)
                                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Time of Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                    config.timeHour = comps.hour ?? 8
                    config.timeMinute = comps.minute ?? 0
                    config.weekdays = Array(selectedWeekdays).sorted()
                    onAdd()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
