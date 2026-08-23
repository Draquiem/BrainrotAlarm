import SwiftUI

struct AlarmEditorView: View {
    @EnvironmentObject private var store: AlarmStore
    @Environment(\.dismiss) private var dismiss

    @State private var alarm: AlarmItem
    @State private var time: Date
    @State private var showingPin = false
    @State private var rehearsal: RingingContext?
    private let isNew: Bool

    init(alarm: AlarmItem, isNew: Bool) {
        _alarm = State(initialValue: alarm)
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        _time = State(initialValue: Calendar.current.date(from: components) ?? Date())
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)

                        Panel(title: "Label") {
                            TextField("Alarm", text: $alarm.label)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)
                        }

                        Panel(title: "Repeat") { repeatPicker }
                        Panel(title: "Difficulty") { difficultyPicker }
                        Panel(title: "Roster") { rosterPicker }
                        Panel(title: "Snooze") { snoozePicker }
                        Panel(title: "Feedback") {
                            Toggle("Haptics on wrong answers", isOn: $alarm.hapticsEnabled)
                                .tint(Theme.accent)
                                .foregroundStyle(.white)
                        }

                        Button {
                            var probe = alarm
                            probe.isEnabled = true
                            rehearsal = RingingContext(alarm: probe, firedAt: Date(), isRehearsal: true)
                        } label: {
                            Label("Rehearse this alarm", systemImage: "play.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surfaceRaised))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)

                        if !isNew {
                            Button(role: .destructive) {
                                store.delete(alarm)
                                dismiss()
                            } label: {
                                Text("Delete alarm")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(hex: 0xFF6B6B))
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(isNew ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
            .fullScreenCover(item: $rehearsal) { context in
                ChallengeView(context: context)
            }
        }
    }

    // MARK: - Sections

    private var repeatPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                let isOn = alarm.repeatDays.contains(day)
                Button {
                    if isOn { alarm.repeatDays.remove(day) } else { alarm.repeatDays.insert(day) }
                } label: {
                    Text(day.initial)
                        .font(.footnote.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(isOn ? Theme.accent : Theme.surfaceRaised))
                        .foregroundStyle(isOn ? .black : Theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Difficulty", selection: $alarm.difficulty) {
                ForEach(Difficulty.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)

            Text(alarm.difficulty.blurb)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rosterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Roster", selection: $alarm.tierCeiling) {
                Text("Famous only").tag(BrainrotCharacter.Tier.starter)
                Text("Wider").tag(BrainrotCharacter.Tier.core)
                Text("Everyone").tag(BrainrotCharacter.Tier.deep)
            }
            .pickerStyle(.segmented)

            Text("\(alarm.pool().count) characters in play.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)

            Divider().overlay(Theme.hairline)

            Toggle("Always ring the same character", isOn: Binding(
                get: { alarm.pinnedCharacterID != nil },
                set: { alarm.pinnedCharacterID = $0 ? alarm.pool().first?.id : nil }))
                .tint(Theme.accent)
                .foregroundStyle(.white)

            if alarm.pinnedCharacterID != nil {
                Picker("Character", selection: Binding(
                    get: { alarm.pinnedCharacterID ?? "" },
                    set: { alarm.pinnedCharacterID = $0 })) {
                    ForEach(alarm.pool()) { character in
                        Text(character.name).tag(character.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)

                Text("You will know who it is — you still have to pick them out of the grid.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var snoozePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(alarm.snoozeMinutes == 0 ? "Snooze off" : "Snooze \(alarm.snoozeMinutes) min",
                    value: $alarm.snoozeMinutes, in: 0...30, step: 1)
                .foregroundStyle(.white)
            if alarm.snoozeMinutes > 0 {
                Stepper("Up to \(alarm.maxSnoozes) times",
                        value: $alarm.maxSnoozes, in: 1...5)
                    .foregroundStyle(.white)
                Text("After that, the only way out is the grid.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    // MARK: - Save

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        alarm.hour = components.hour ?? 7
        alarm.minute = components.minute ?? 0
        if alarm.label.trimmingCharacters(in: .whitespaces).isEmpty { alarm.label = "Alarm" }
        // A pinned character that is no longer in the chosen tier would never ring.
        if let pinned = alarm.pinnedCharacterID, !alarm.pool().contains(where: { $0.id == pinned }) {
            alarm.pinnedCharacterID = alarm.pool().first?.id
        }
        if isNew { store.add(alarm) } else { store.update(alarm) }
        dismiss()
    }
}
