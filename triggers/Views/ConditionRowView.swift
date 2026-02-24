import SwiftUI

struct ConditionRowView: View {
    let condition: Condition
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: condition.type.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(condition.type.displayName)
                    .font(.subheadline.bold())
                Text(condition.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
