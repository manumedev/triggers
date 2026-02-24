import SwiftUI
import SwiftData

struct HomeView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RulesListViewModel()
    @State private var showingNewRuleBuilder = false
    @State private var editingRule: Rule? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredRules.isEmpty {
                    emptyState
                } else {
                    rulesList
                }
            }
            .navigationTitle("Triggers")
            .searchable(text: $viewModel.searchText, prompt: "Search rules")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewRuleBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingNewRuleBuilder, onDismiss: {
                viewModel.loadRules()
            }) {
                RuleBuilderView(editingRule: nil)
            }
            .sheet(item: $editingRule, onDismiss: {
                viewModel.loadRules()
            }) { rule in
                RuleBuilderView(editingRule: rule)
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }

    // MARK: - Subviews

    private var rulesList: some View {
        List {
            ForEach(viewModel.filteredRules) { rule in
                RuleRowView(rule: rule) {
                    viewModel.toggle(rule: rule)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingRule = rule
                }
            }
            .onDelete { offsets in
                viewModel.deleteRules(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Rules Yet")
                .font(.title2.bold())
            Text("Tap + to create your first smart reminder rule.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Create First Rule") {
                showingNewRuleBuilder = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Rule Row

struct RuleRowView: View {
    let rule: Rule
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.headline)
                    .foregroundStyle(rule.isEnabled ? .primary : .secondary)

                // Condition summary
                let conditions = rule.conditions
                if conditions.isEmpty {
                    Text("No conditions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    conditionSummaryText(conditions: conditions, logic: rule.conditionLogic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func conditionSummaryText(conditions: [Condition], logic: ConditionLogic) -> Text {
        let separator = " \(logic.displayName) "
        let parts = conditions.map { $0.summary }
        return Text(parts.joined(separator: separator))
    }
}
