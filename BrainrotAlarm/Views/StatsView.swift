import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: AlarmStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            StatTile(value: "\(store.currentStreak)", label: "day streak")
                            StatTile(value: "\(store.wakeLog.count)", label: "wake-ups")
                        }
                        HStack(spacing: 12) {
                            StatTile(value: averageDismissal, label: "avg. to dismiss")
                            StatTile(value: accuracy, label: "first-try rate")
                        }

                        if let nemesis {
                            Panel(title: "Your nemesis") {
                                HStack(spacing: 14) {
                                    CreatureView(recipe: nemesis.character.art, assetID: nemesis.character.id)
                                        .frame(width: 62, height: 62)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(nemesis.character.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("\(nemesis.misses) wrong guesses across \(nemesis.appearances) alarms")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                        }

                        if store.wakeLog.isEmpty {
                            Text("Nothing logged yet. Rehearsals and practice rounds do not count.")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                        } else {
                            Panel(title: "Recent") {
                                VStack(spacing: 0) {
                                    ForEach(store.wakeLog.prefix(12)) { record in
                                        WakeRow(record: record)
                                        if record.id != store.wakeLog.prefix(12).last?.id {
                                            Divider().overlay(Theme.hairline)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Record")
        }
    }

    private var averageDismissal: String {
        guard !store.wakeLog.isEmpty else { return "—" }
        let mean = store.wakeLog.map(\.secondsToDismiss).reduce(0, +) / Double(store.wakeLog.count)
        return "\(Int(mean.rounded()))s"
    }

    private var accuracy: String {
        guard !store.wakeLog.isEmpty else { return "—" }
        let clean = store.wakeLog.filter { $0.misses == 0 }.count
        return "\(Int((Double(clean) / Double(store.wakeLog.count) * 100).rounded()))%"
    }

    /// Whoever you have got wrong the most.
    private var nemesis: (character: BrainrotCharacter, misses: Int, appearances: Int)? {
        var misses: [String: Int] = [:]
        var appearances: [String: Int] = [:]
        for record in store.wakeLog {
            misses[record.characterID, default: 0] += record.misses
            appearances[record.characterID, default: 0] += 1
        }
        guard let worst = misses.filter({ $0.value > 0 }).max(by: { $0.value < $1.value }),
              let character = BrainrotCatalog.character(id: worst.key) else { return nil }
        return (character, worst.value, appearances[worst.key] ?? 0)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
    }
}

private struct WakeRow: View {
    let record: WakeRecord

    var body: some View {
        HStack(spacing: 12) {
            if let character = BrainrotCatalog.character(id: record.characterID) {
                CreatureView(recipe: character.art, assetID: character.id)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(record.date, format: .dateTime.weekday().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(record.secondsToDismiss.rounded()))s")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                Text(record.misses == 0 ? "clean" : "\(record.misses) wrong")
                    .font(.caption2)
                    .foregroundStyle(record.misses == 0 ? Color(hex: 0x5CE08A) : Theme.secondaryText)
            }
        }
        .padding(.vertical, 9)
    }
}
