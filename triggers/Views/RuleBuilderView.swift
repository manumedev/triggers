import SwiftUI
import SwiftData

struct RuleBuilderView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingRule: Rule?

    @State private var viewModel = RuleBuilderViewModel()
    @State private var showingTriggerPicker = false
    @State private var showingRepeatPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Rule identity
                Section("Rule Name") {
                    TextField("e.g. Leaving Home", text: $viewModel.name)
                }

                // MARK: Notification content
                Section("Notification") {
                    TextField("Title (optional)", text: $viewModel.notificationTitle)
                    TextField("Message (required)", text: $viewModel.notificationBody, axis: .vertical)
                        .lineLimit(3...6)
                }

                // MARK: Conditions
                Section {
                    ForEach(Array(viewModel.conditions.enumerated()), id: \.element.id) { index, condition in
                        VStack(alignment: .leading, spacing: 4) {
                            // AND/OR separator between conditions
                            if index > 0 {
                                logicPill
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }
                            ConditionRowView(condition: condition) {
                                viewModel.removeCondition(at: IndexSet(integer: index))
                            }
                        }
                    }
                    .onMove { from, to in
                        viewModel.moveCondition(from: from, to: to)
                    }

                    Button {
                        showingTriggerPicker = true
                    } label: {
                        Label("Add Condition", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Conditions")
                        Spacer()
                        if viewModel.conditions.count > 1 {
                            Text(viewModel.conditionLogic.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Repeat
                Section("Repeat") {
                    Picker("Repeat", selection: $viewModel.repeatBehavior) {
                        Text("Once").tag(RepeatBehavior.once)
                        Text("Every time").tag(RepeatBehavior.always)
                        Text("Once per hour").tag(RepeatBehavior.cooldown(minutes: 60))
                        Text("Once per day").tag(RepeatBehavior.cooldown(minutes: 1440))
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Preview
                if !viewModel.conditions.isEmpty {
                    Section("Preview") {
                        rulePreview
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Rule" : "New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showingTriggerPicker) {
                TriggerPickerView { condition in
                    viewModel.addCondition(condition)
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            if let rule = editingRule {
                viewModel.load(rule: rule)
            }
        }
    }

    // MARK: - Subviews

    private var logicPill: some View {
        Button {
            viewModel.conditionLogic = viewModel.conditionLogic == .and ? .or : .and
        } label: {
            Text(viewModel.conditionLogic.displayName)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var rulePreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This rule fires when:")
                .font(.caption)
                .foregroundStyle(.secondary)
            let parts = viewModel.conditions.map { $0.summary }
            let sep = " \(viewModel.conditionLogic.displayName) "
            Text(parts.joined(separator: sep))
                .font(.subheadline)

            if !viewModel.notificationBody.isEmpty {
                Divider()
                Label(viewModel.notificationTitle.isEmpty ? viewModel.name : viewModel.notificationTitle,
                      systemImage: "bell.fill")
                    .font(.caption.bold())
                Text(viewModel.notificationBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
