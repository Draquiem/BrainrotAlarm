import XCTest
@testable import BrainrotAlarm

final class ChantParserTests: XCTestCase {

    func testSplitsWordsAndSyllables() {
        let phrase = ChantParser.parse("Tra-la-le-ro Tra-la-la")
        XCTAssertEqual(phrase.words.count, 2)
        XCTAssertEqual(phrase.words[0].count, 4)
        XCTAssertEqual(phrase.words[1].count, 3)
        XCTAssertEqual(phrase.syllableCount, 7)
    }

    func testStressDefaultsToPenultimateSyllable() {
        let phrase = ChantParser.parse("Bom-bar-di-ro")
        let stressed = phrase.words[0].enumerated().filter { $0.element.stressed }.map(\.offset)
        XCTAssertEqual(stressed, [2], "Italian default stress is the second-to-last syllable")
    }

    func testAccentedVowelCarriesStress() {
        let phrase = ChantParser.parse("Li-ri-lì")
        XCTAssertTrue(phrase.words[0][2].stressed)
        XCTAssertFalse(phrase.words[0][0].stressed)
        // The accent must not survive into the vowel identity.
        XCTAssertEqual(phrase.words[0][2].vowel, .i)
    }

    func testExplicitStressMarkerWins() {
        let phrase = ChantParser.parse("'Bom-bar-di-ro")
        XCTAssertTrue(phrase.words[0][0].stressed)
        XCTAssertFalse(phrase.words[0][2].stressed, "an explicit marker suppresses the default")
    }

    func testConsonantClassification() {
        let phrase = ChantParser.parse("Pa Ba Ta Da Ca Ga Fa Sa Ma La Ra")
        let onsets = phrase.words.map { $0[0].onset }
        XCTAssertEqual(onsets[0], .plosive(place: .labial, voiced: false))
        XCTAssertEqual(onsets[1], .plosive(place: .labial, voiced: true))
        XCTAssertEqual(onsets[2], .plosive(place: .dental, voiced: false))
        XCTAssertEqual(onsets[3], .plosive(place: .dental, voiced: true))
        XCTAssertEqual(onsets[4], .plosive(place: .velar, voiced: false))
        XCTAssertEqual(onsets[5], .plosive(place: .velar, voiced: true))
        XCTAssertEqual(onsets[6], .fricative(place: .labial, voiced: false))
        XCTAssertEqual(onsets[7], .fricative(place: .dental, voiced: false))
        XCTAssertEqual(onsets[8], .nasal)
        XCTAssertEqual(onsets[9], .liquid(rhotic: false))
        XCTAssertEqual(onsets[10], .liquid(rhotic: true))
    }

    func testSoftCBeforeFrontVowelIsAnAffricate() {
        XCTAssertEqual(ChantParser.parse("ci").words[0][0].onset, .fricative(place: .dental, voiced: false))
        XCTAssertEqual(ChantParser.parse("ca").words[0][0].onset, .plosive(place: .velar, voiced: false))
    }

    func testVowellessTokenBecomesATrill() {
        let phrase = ChantParser.parse("Brr")
        XCTAssertEqual(phrase.words[0][0].onset, .trill)
        XCTAssertTrue(phrase.words[0][0].coda)
    }

    func testCodaAndLiquidReleaseDetection() {
        let tung = ChantParser.parse("Tung").words[0][0]
        XCTAssertTrue(tung.coda)
        XCTAssertFalse(tung.liquidRelease)

        let tra = ChantParser.parse("Tra").words[0][0]
        XCTAssertFalse(tra.coda)
        XCTAssertTrue(tra.liquidRelease, "the r in 'tr' should glide into the vowel")
    }

    func testEmptyInput() {
        XCTAssertTrue(ChantParser.parse("").isEmpty)
        XCTAssertTrue(ChantParser.parse("   ").isEmpty)
        XCTAssertTrue(ChantParser.parse("---").isEmpty)
    }

    func testEveryCatalogChantParses() {
        for character in BrainrotCatalog.all {
            let phrase = ChantParser.parse(character.chant)
            XCTAssertFalse(phrase.isEmpty, "\(character.id) produced no syllables")
            XCTAssertGreaterThanOrEqual(phrase.syllableCount, 2, "\(character.id) is too short to identify")
        }
    }
}

final class ChantSynthTests: XCTestCase {

    private let voice = VoiceProfile.goofball

    func testRendersAudibleAudio() {
        let samples = ChantSynth.render(chant: "Tra-la-le-ro Tra-la-la", voice: voice)
        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite }, "no NaN or infinity may reach the buffer")

        let peak = samples.map(abs).max() ?? 0
        XCTAssertEqual(peak, 0.89, accuracy: 0.02, "output is normalised to a fixed headroom")

        let rms = (samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count)).squareRoot()
        XCTAssertGreaterThan(rms, 0.05, "an alarm this quiet would not wake anyone")
        XCTAssertLessThan(rms, 0.45)
    }

    func testCrestFactorIsSpeechLike() {
        // A single spike towering over the vowels is the classic failure here; it
        // sounds like a click, not a voice.
        for character in BrainrotCatalog.all {
            let samples = ChantSynth.render(chant: character.chant, voice: character.voice)
            let peak = Double(samples.map(abs).max() ?? 0)
            let rms = (samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count)).squareRoot()
            let crest = 20 * log10(peak / max(rms, 1e-9))
            XCTAssertLessThan(crest, 22, "\(character.id) is too peaky (\(crest) dB)")
            XCTAssertGreaterThan(crest, 6, "\(character.id) is over-compressed (\(crest) dB)")
        }
    }

    func testRenderIsDeterministicForAGivenSeed() {
        let a = ChantSynth.render(chant: "Bom-bar-di-ro", voice: .bruiser, seed: 99)
        let b = ChantSynth.render(chant: "Bom-bar-di-ro", voice: .bruiser, seed: 99)
        XCTAssertEqual(a, b)

        let c = ChantSynth.render(chant: "Bom-bar-di-ro", voice: .bruiser, seed: 100)
        XCTAssertNotEqual(a, c, "a different seed should change the noise components")
    }

    func testDurationTracksTempo() {
        let slow = ChantSynth.render(chant: "La-la-la-la", voice: voice.with { $0.tempo = 2 })
        let fast = ChantSynth.render(chant: "La-la-la-la", voice: voice.with { $0.tempo = 5 })
        XCTAssertGreaterThan(slow.count, fast.count)
    }

    func testEmptyChantRendersNothing() {
        XCTAssertTrue(ChantSynth.render(chant: "", voice: voice).isEmpty)
    }

    func testFormantResonatorsLandOnTarget() {
        // Drive the filter bank with an impulse and confirm the peaks sit where the
        // vowel table says they should.
        for vowel in Syllable.Vowel.allCases {
            let (f1, f2, _) = vowel.formants
            let (b1, b2, _) = vowel.bandwidths
            var low = Biquad(sampleRate: 44_100)
            var mid = Biquad(sampleRate: 44_100)
            low.setBandpass(centerHz: f1, bandwidthHz: b1)
            mid.setBandpass(centerHz: f2, bandwidthHz: b2)

            XCTAssertEqual(peakFrequency(of: &low), f1, accuracy: f1 * 0.05,
                           "F1 of /\(vowel.rawValue)/ drifted")
            XCTAssertEqual(peakFrequency(of: &mid), f2, accuracy: f2 * 0.05,
                           "F2 of /\(vowel.rawValue)/ drifted")
        }
    }

    /// Sweeps a sine through the filter and returns the frequency with the most output.
    private func peakFrequency(of filter: inout Biquad) -> Double {
        var best = 0.0
        var bestEnergy = 0.0
        var probe = 100.0
        while probe < 4_000 {
            var copy = filter
            copy.reset()
            var energy = 0.0
            for n in 0..<1_024 {
                let x = sin(2 * .pi * probe * Double(n) / 44_100)
                let y = copy.process(x)
                if n > 256 { energy += y * y }      // let the filter settle first
            }
            if energy > bestEnergy { bestEnergy = energy; best = probe }
            probe += 10
        }
        return best
    }
}
