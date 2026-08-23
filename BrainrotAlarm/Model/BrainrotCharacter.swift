import Foundation

/// One member of the roster: a name, the chant the alarm sings, the voice that
/// sings it, and the recipe for the picture you have to tap.
struct BrainrotCharacter: Identifiable, Equatable {

    /// Loose grouping used to pick plausible wrong answers.
    enum Family: String, CaseIterable {
        case aquatic, aviator, primate, bovine, reptile, confection, flora, oddity

        var label: String {
            switch self {
            case .aquatic: return "Aquatic"
            case .aviator: return "Airborne"
            case .primate: return "Primate"
            case .bovine: return "Hoofed"
            case .reptile: return "Reptile"
            case .confection: return "Edible"
            case .flora: return "Botanical"
            case .oddity: return "Unclassified"
            }
        }
    }

    /// How well known the character is. Easy alarms draw from `starter` only.
    enum Tier: Int, Comparable {
        case starter = 0, core = 1, deep = 2
        static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }
    }

    let id: String
    let name: String
    /// Hyphen-separated syllables; see `ChantParser`.
    let chant: String
    let tagline: String
    let family: Family
    let tier: Tier
    let voice: VoiceProfile
    let art: CreatureRecipe

    /// Mean fundamental across the melody, in Hz. The single strongest cue for
    /// telling two chants apart, so distractor picking leans on it.
    var averagePitch: Double {
        let steps = max(1, voice.melody.count)
        let sum = (0..<steps).reduce(0.0) { total, index in
            total + voice.fundamental * pow(2, voice.semitoneOffset(atSyllable: index) / 12)
        }
        return sum / Double(steps)
    }

    var syllableCount: Int { ChantParser.parse(chant).syllableCount }

    /// 0 = indistinguishable, larger = easier to tell apart.
    ///
    /// Mirrors the offline analysis used to tune the roster: pitch dominates,
    /// then speaking rate, then length, with a penalty for sharing a family so
    /// that same-family look-alikes stay together on hard difficulties.
    func distance(to other: BrainrotCharacter) -> Double {
        let pitch = abs(log2(max(1, averagePitch)) - log2(max(1, other.averagePitch))) * 4
        let rate = abs(voice.tempo - other.voice.tempo) * 0.45
        let length = abs(Double(syllableCount - other.syllableCount)) * 0.28
        let familyBonus = family == other.family ? 0.0 : 0.7
        return pitch + rate + length + familyBonus
    }
}
