import SwiftUI

/// Browse and listen to everyone, so the alarm is not the first time you hear them.
struct RosterView: View {
    @State private var selected: BrainrotCharacter?
    @State private var practice: RingingContext?
    @State private var tierFilter: BrainrotCharacter.Tier = .deep

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        practiceButton
                        Picker("Tier", selection: $tierFilter) {
                            Text("Famous").tag(BrainrotCharacter.Tier.starter)
                            Text("Wider").tag(BrainrotCharacter.Tier.core)
                            Text("Everyone").tag(BrainrotCharacter.Tier.deep)
                        }
                        .pickerStyle(.segmented)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(BrainrotCatalog.characters(upTo: tierFilter)) { character in
                                CreatureTile(character: character, showsName: true) {
                                    selected = character
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Roster")
            .sheet(item: $selected) { character in
                CharacterDetailView(character: character)
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $practice) { context in
                ChallengeView(context: context)
            }
        }
    }

    private var practiceButton: some View {
        Button {
            var drill = AlarmItem(label: "Practice", difficulty: .standard, tierCeiling: tierFilter)
            drill.snoozeMinutes = 0
            practice = RingingContext(alarm: drill, firedAt: Date(), isRehearsal: true)
        } label: {
            HStack {
                Image(systemName: "ear.badge.waveform")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice round").font(.headline)
                    Text("Same game, no alarm attached.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

@MainActor
struct CharacterDetailView: View {
    let character: BrainrotCharacter
    @StateObject private var audio = AlarmAudioEngine.shared

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    CreatureView(recipe: character.art, assetID: character.id)
                        .frame(maxWidth: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    VStack(spacing: 6) {
                        Text(character.name)
                            .font(.title2.weight(.heavy))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        Text(character.tagline)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack(spacing: 8) {
                        Badge(text: character.family.label)
                        Badge(text: tierName, tint: Theme.secondaryText)
                        Badge(text: "\(character.syllableCount) syllables", tint: Theme.secondaryText)
                    }

                    Button {
                        Task { await audio.preview(character) }
                    } label: {
                        Label("Play the chant", systemImage: "speaker.wave.3.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Panel(title: "Chant") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(character.chant.replacingOccurrences(of: "-", with: "\u{2011}"))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(voiceSummary)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var tierName: String {
        switch character.tier {
        case .starter: return "Famous"
        case .core: return "Known"
        case .deep: return "Obscure"
        }
    }

    private var voiceSummary: String {
        let pitch = Int(character.averagePitch.rounded())
        let tempo = String(format: "%.1f", character.voice.tempo)
        return "≈\(pitch) Hz · \(tempo) syllables per second"
    }
}
