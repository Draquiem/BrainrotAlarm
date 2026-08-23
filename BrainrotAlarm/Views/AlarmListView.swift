import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject private var store: AlarmStore
    @State private var editing: AlarmItem?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if store.alarms.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $isCreating) {
                AlarmEditorView(alarm: AlarmItem(), isNew: true)
            }
            .sheet(item: $editing) { alarm in
                AlarmEditorView(alarm: alarm, isNew: false)
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let next = nextAlarmDescription {
                    Text(next)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                ForEach(store.alarms) { alarm in
                    AlarmRow(alarm: alarm,
                             onToggle: { store.setEnabled($0, for: alarm) },
                             onTap: { editing = alarm })
                    .contextMenu {
                        Button(role: .destructive) { store.delete(alarm) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "alarm.waves.left.and.right")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accent)
            Text("No alarms yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("Add one and it will wake you with a chant you have to identify.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 40)
            Button("Add an alarm") { isCreating = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(.top, 6)
        }
    }

    private var nextAlarmDescription: String? {
        let upcoming = store.alarms
            .compactMap { $0.nextFireDate() }
            .min()
        guard let upcoming else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Next alarm \(formatter.localizedString(for: upcoming, relativeTo: Date()))"
    }
}

private struct AlarmRow: View {
    let alarm: AlarmItem
    let onToggle: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(alarm.formattedTime())
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(alarm.isEnabled ? .white : Theme.secondaryText)
                    HStack(spacing: 6) {
                        Text(alarm.label.isEmpty ? "Alarm" : alarm.label)
                        Text("·")
                        Text(alarm.repeatDescription)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    HStack(spacing: 6) {
                        Badge(text: alarm.difficulty.title, tint: difficultyTint)
                        Badge(text: "\(alarm.difficulty.gridCount) tiles", tint: Theme.secondaryText)
                        if alarm.pinnedCharacterID != nil {
                            Badge(text: "Pinned", tint: Theme.secondaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: onToggle))
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
    }

    private var difficultyTint: Color {
        switch alarm.difficulty {
        case .gentle: return Color(hex: 0x5CE08A)
        case .standard: return Theme.accent
        case .brutal: return Color(hex: 0xFFB03A)
        case .nightmare: return Color(hex: 0xFF6B6B)
        }
    }
}

struct Badge: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.16)))
            .foregroundStyle(tint)
    }
}
