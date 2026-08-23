import Foundation

/// One spoken beat of a chant, e.g. `Tra` inside `Tra-la-le-ro`.
///
/// The synthesiser is a source-filter model: `onset` shapes the short consonant
/// transient, `vowel` selects the formant target that the voiced body resonates at,
/// and `coda` clips the tail so closed syllables (`Tung`, `Brr`) land harder than
/// open ones (`la`, `ro`).
struct Syllable: Equatable {

    enum Onset: Equatable {
        case none
        /// p t k / b d g — silence, then a filtered burst.
        case plosive(place: Place, voiced: Bool)
        /// f s sh / v z — sustained band-limited noise.
        case fricative(place: Place, voiced: Bool)
        /// m n gn — voiced, heavily damped, low first formant.
        case nasal
        /// l r — voiced formant glide into the vowel.
        case liquid(rhotic: Bool)
        /// The trilled `Brr` of Brr Brr Patapim gets its own amplitude flutter.
        case trill
    }

    /// Rough articulation point. Drives the centre frequency of the burst filter.
    enum Place: Equatable {
        case labial   // p b f v m
        case dental   // t d s z n l r
        case velar    // k g

        var burstHz: Double {
            switch self {
            case .labial: return 900
            case .dental: return 3800
            case .velar:  return 1900
            }
        }

        var burstQ: Double {
            switch self {
            case .labial: return 1.2
            case .dental: return 2.4
            case .velar:  return 3.0
            }
        }
    }

    /// The five Italian vowels. Formant values are classic adult-male measurements
    /// (Hz), later scaled per character by `VoiceProfile.formantScale`.
    enum Vowel: String, CaseIterable, Equatable {
        case a, e, i, o, u

        /// F1, F2, F3.
        var formants: (Double, Double, Double) {
            switch self {
            case .a: return (730, 1090, 2440)
            case .e: return (530, 1840, 2480)
            case .i: return (270, 2290, 3010)
            case .o: return (570,  840, 2410)
            case .u: return (300,  870, 2240)
            }
        }

        /// Bandwidths for each formant, in Hz. Narrower reads as more "sung".
        var bandwidths: (Double, Double, Double) { (70, 100, 150) }

        /// Open vowels carry more energy than close ones.
        var openness: Double {
            switch self {
            case .a: return 1.0
            case .e, .o: return 0.85
            case .i, .u: return 0.7
            }
        }
    }

    var onset: Onset
    var vowel: Vowel
    /// True when the syllable ends on a consonant (`Tung`, `Bom`), which shortens
    /// the vowel body and adds a damped nasal/stop tail.
    var coda: Bool
    /// True for a stressed syllable — gets a pitch accent and extra length.
    var stressed: Bool
    /// True when the onset cluster ends in `l` or `r` (`Tra`, `Cro`, `Glor`).
    /// The vowel formants slide in from a liquid position instead of starting flat,
    /// which is most of what makes these names sound Italian rather than robotic.
    var liquidRelease: Bool
    /// The original text, kept for captions and debugging.
    var text: String

    /// Relative duration multiplier before the voice's tempo is applied.
    var lengthFactor: Double {
        var f = 1.0
        if stressed { f *= 1.35 }
        if coda { f *= 0.8 }
        if case .trill = onset { f *= 1.2 }
        return f
    }
}

/// A full chant: words, each a run of syllables. Word gaps become short breaths.
struct ChantPhrase: Equatable {
    var words: [[Syllable]]

    var syllables: [Syllable] { words.flatMap { $0 } }
    var syllableCount: Int { words.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { syllables.isEmpty }
}
