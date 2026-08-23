import Foundation

/// Everything that makes one brainrot voice sound unlike the others.
///
/// The point of the app is that you can tell `Bombardiro Crocodilo` from
/// `Ballerina Cappuccina` while half asleep, so these are deliberately spread far
/// apart: pitch across three octaves, tempo from a plod to a patter, and melodies
/// that outline different shapes.
struct VoiceProfile: Equatable {
    /// Fundamental pitch in Hz for scale degree 0.
    var fundamental: Double = 138
    /// Vocal-tract length proxy. Below 1 is a bigger head and a darker vowel;
    /// above 1 is small and squeaky.
    var formantScale: Double = 1.0
    /// Syllables per second.
    var tempo: Double = 3.4
    /// 0 is metronomic, 1 is a hard long-short shuffle.
    var swing: Double = 0
    /// Semitone offsets of the mode the melody walks through.
    var scale: [Int] = [0, 2, 4, 5, 7, 9, 11]
    /// Scale degrees, one per syllable, cycled. Degrees may run past the end of
    /// `scale` or go negative; they wrap into higher and lower octaves.
    var melody: [Int] = [0, 2, 4, 2]
    var vibratoRate: Double = 5.2
    /// Vibrato width in semitones.
    var vibratoDepth: Double = 0.18
    /// Aspiration noise mixed into the glottal source, 0...1.
    var breathiness: Double = 0.06
    /// Waveshaper drive plus period-doubling, 0...1. Past ~0.5 it reads as a growl.
    var growl: Double = 0.15
    /// Semitones of downward pitch drift across the whole phrase. Without this a
    /// chant sounds like a ringtone instead of a voice.
    var declination: Double = 2.0
    /// Breath length between words, in seconds.
    var wordGap: Double = 0.13
    /// Raises F3 and tilts the source spectrum up, 0...1.
    var brightness: Double = 0.5

    /// Absolute semitone offset for a melody degree, wrapping into octaves.
    func semitoneOffset(forDegree degree: Int) -> Double {
        guard !scale.isEmpty else { return 0 }
        let n = scale.count
        let octave = Int(floor(Double(degree) / Double(n)))
        let index = degree - octave * n
        return Double(scale[index] + 12 * octave)
    }

    func semitoneOffset(atSyllable index: Int) -> Double {
        guard !melody.isEmpty else { return 0 }
        let degree = melody[((index % melody.count) + melody.count) % melody.count]
        return semitoneOffset(forDegree: degree)
    }
}

// MARK: - Presets

extension VoiceProfile {
    static let minorScale = [0, 2, 3, 5, 7, 8, 10]
    static let majorScale = [0, 2, 4, 5, 7, 9, 11]
    static let pentatonic = [0, 3, 5, 7, 10]
    static let wholeTone  = [0, 2, 4, 6, 8, 10]

    /// Cartoon baritone. The default "guy doing a silly voice" register.
    static let goofball = VoiceProfile(
        fundamental: 128, formantScale: 0.96, tempo: 3.6, swing: 0.25,
        scale: majorScale, melody: [0, 2, 4, 2], vibratoRate: 5.0, vibratoDepth: 0.2,
        breathiness: 0.05, growl: 0.2, declination: 2.0, wordGap: 0.13, brightness: 0.5)

    /// Very low, slow, menacing. For anything with a bomb attached to it.
    static let bruiser = VoiceProfile(
        fundamental: 82, formantScale: 0.82, tempo: 2.7, swing: 0.15,
        scale: minorScale, melody: [0, 0, -3, 0, 2], vibratoRate: 4.2, vibratoDepth: 0.12,
        breathiness: 0.04, growl: 0.55, declination: 3.0, wordGap: 0.17, brightness: 0.3)

    /// Squeaky and fast — small creatures, fruit-based creatures.
    static let squeaker = VoiceProfile(
        fundamental: 268, formantScale: 1.28, tempo: 5.0, swing: 0.35,
        scale: pentatonic, melody: [0, 3, 2, 4, 2], vibratoRate: 6.4, vibratoDepth: 0.3,
        breathiness: 0.1, growl: 0.08, declination: 1.4, wordGap: 0.1, brightness: 0.8)

    /// Wide vibrato, slow, self-important. Opera-adjacent.
    static let diva = VoiceProfile(
        fundamental: 232, formantScale: 1.1, tempo: 2.5, swing: 0.05,
        scale: majorScale, melody: [4, 2, 0, 2, 4, 7], vibratoRate: 5.6, vibratoDepth: 0.55,
        breathiness: 0.09, growl: 0.05, declination: 2.6, wordGap: 0.2, brightness: 0.68)

    /// Nasal, clipped, percussive. Reads as chanting rather than singing.
    static let chanter = VoiceProfile(
        fundamental: 146, formantScale: 0.92, tempo: 4.2, swing: 0.0,
        scale: [0, 1, 5, 7], melody: [0, 0, 0, 1, 0], vibratoRate: 7.0, vibratoDepth: 0.1,
        breathiness: 0.03, growl: 0.3, declination: 1.0, wordGap: 0.1, brightness: 0.42)

    /// Unsettling and unresolved — the whole-tone scale never picks a home note.
    static let eerie = VoiceProfile(
        fundamental: 174, formantScale: 1.02, tempo: 3.0, swing: 0.4,
        scale: wholeTone, melody: [0, 2, 1, 3, 2, 5], vibratoRate: 3.4, vibratoDepth: 0.42,
        breathiness: 0.16, growl: 0.12, declination: 0.5, wordGap: 0.16, brightness: 0.6)

    func with(_ transform: (inout VoiceProfile) -> Void) -> VoiceProfile {
        var copy = self
        transform(&copy)
        return copy
    }
}
