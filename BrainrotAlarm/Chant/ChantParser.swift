import Foundation

/// Turns a written chant into the phoneme structure the synthesiser can sing.
///
/// Input format, as stored on every `BrainrotCharacter`:
///
///     "Tra-la-le-ro Tra-la-la"     hyphens split syllables, spaces split words
///     "Tung Tung Tung Sa-hur"      single-syllable words are fine
///     "Li-ri-lì La-ri-là"          an accented vowel marks stress
///     "Bom-bar-'di-ro"             a leading apostrophe forces stress
///
/// With no explicit marker the parser falls back to the Italian default of
/// stressing the penultimate syllable of each word.
enum ChantParser {

    static func parse(_ chant: String) -> ChantPhrase {
        let words = chant
            .split(whereSeparator: { $0 == " " || $0 == "\u{00A0}" })
            .map { parseWord(String($0)) }
            .filter { !$0.isEmpty }
        return ChantPhrase(words: words)
    }

    // Takes a concrete String rather than `some StringProtocol` deliberately. With a
    // generic receiver the SubSequence type stays open, and `String.init` has enough
    // overloads that Swift cannot then pick one — which it reports, confusingly, as
    // an ambiguous `split`.
    private static func parseWord(_ word: String) -> [Syllable] {
        let tokens: [String] = word.split(separator: "-" as Character).map { String($0) }
        var syllables = tokens.compactMap(parseSyllable)
        guard !syllables.isEmpty else { return [] }

        // Only apply the penultimate default when the author marked nothing.
        if !syllables.contains(where: { $0.stressed }) {
            let index = syllables.count >= 2 ? syllables.count - 2 : 0
            syllables[index].stressed = true
        }
        return syllables
    }

    private static func parseSyllable(_ raw: String) -> Syllable? {
        var forcedStress = false
        var body = raw
        if body.hasPrefix("'") || body.hasPrefix("\u{2019}") {
            forcedStress = true
            body.removeFirst()
        }

        // Accented vowels carry stress in Italian, so detect them before folding.
        let accented = body.contains { accentedVowels.contains($0) }
        let letters = Array(fold(body))
        guard !letters.isEmpty else { return nil }

        guard let vowelIndex = letters.firstIndex(where: { vowelMap[$0] != nil }) else {
            // A vowelless token such as "Brr" or "Tst": a pure trill/rasp.
            return Syllable(onset: .trill,
                            vowel: .u,
                            coda: true,
                            stressed: true,
                            liquidRelease: false,
                            text: raw)
        }

        let onsetCluster = Array(letters[..<vowelIndex])
        let vowel = vowelMap[letters[vowelIndex]] ?? .a

        // Skip any vowel run ("uo", "ia") — the first vowel sets the formant target.
        var tailIndex = vowelIndex + 1
        while tailIndex < letters.count, vowelMap[letters[tailIndex]] != nil { tailIndex += 1 }
        let hasCoda = tailIndex < letters.count

        let nextVowel = vowelIndex + 1 < letters.count ? letters[vowelIndex + 1] : nil
        let liquidRelease = onsetCluster.count > 1 && (onsetCluster.last == "l" || onsetCluster.last == "r")

        return Syllable(onset: onset(for: onsetCluster, followingVowel: letters[vowelIndex], thenVowel: nextVowel),
                        vowel: vowel,
                        coda: hasCoda,
                        stressed: forcedStress || accented,
                        liquidRelease: liquidRelease,
                        text: raw)
    }

    // MARK: - Consonants

    private static func onset(for cluster: [Character],
                              followingVowel: Character,
                              thenVowel: Character?) -> Syllable.Onset {
        guard let first = cluster.first else { return .none }

        // Digraphs, checked before single letters because they change place.
        if cluster.count >= 2 {
            let pair = String(cluster[0...1])
            switch pair {
            case "gn": return .nasal
            case "gl": return .liquid(rhotic: false)
            case "ch", "gh": return .plosive(place: .velar, voiced: pair == "gh")
            case "sc" where isFrontVowel(followingVowel): return .fricative(place: .dental, voiced: false)
            default: break
            }
        }

        switch first {
        case "p": return .plosive(place: .labial, voiced: false)
        case "b": return .plosive(place: .labial, voiced: true)
        case "t": return .plosive(place: .dental, voiced: false)
        case "d": return .plosive(place: .dental, voiced: true)
        case "k", "q": return .plosive(place: .velar, voiced: false)
        // Italian soft c/g before e or i are affricates; the fricative branch is
        // the closer of the two available shapes.
        case "c": return isFrontVowel(followingVowel)
            ? .fricative(place: .dental, voiced: false)
            : .plosive(place: .velar, voiced: false)
        case "g": return isFrontVowel(followingVowel)
            ? .fricative(place: .dental, voiced: true)
            : .plosive(place: .velar, voiced: true)
        case "f": return .fricative(place: .labial, voiced: false)
        case "v": return .fricative(place: .labial, voiced: true)
        case "s": return .fricative(place: .dental, voiced: false)
        case "z": return .fricative(place: .dental, voiced: true)
        case "m", "n": return .nasal
        case "l": return .liquid(rhotic: false)
        case "r": return .liquid(rhotic: true)
        case "j", "w", "y": return .liquid(rhotic: false)
        case "h": return .none          // silent in Italian
        default: return .none
        }
    }

    private static func isFrontVowel(_ c: Character) -> Bool { c == "e" || c == "i" }

    // MARK: - Character tables

    private static let vowelMap: [Character: Syllable.Vowel] = [
        "a": .a, "e": .e, "i": .i, "o": .o, "u": .u, "y": .i
    ]

    private static let accentedVowels: Set<Character> = [
        "à", "á", "â", "ä", "è", "é", "ê", "ë", "ì", "í", "î", "ï",
        "ò", "ó", "ô", "ö", "ù", "ú", "û", "ü",
        "À", "Á", "Â", "Ä", "È", "É", "Ê", "Ë", "Ì", "Í", "Î", "Ï",
        "Ò", "Ó", "Ô", "Ö", "Ù", "Ú", "Û", "Ü"
    ]

    /// Lowercases, strips accents, and drops anything that is not a Latin letter.
    private static func fold(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        return String(folded.unicodeScalars.filter { CharacterSet.lowercaseLetters.contains($0) })
    }
}
