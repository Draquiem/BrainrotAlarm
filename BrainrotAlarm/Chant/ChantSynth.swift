import Foundation

/// Sings a `ChantPhrase` in a given `VoiceProfile` and hands back mono PCM.
///
/// This is a classic source-filter voice: a Rosenberg glottal pulse is
/// differentiated to approximate lip radiation, then passed through three
/// resonators parked on the vowel's formants. Consonants come from a separate
/// noise path with its own bandpass, and from the fact that the formants *move* —
/// a burst alone sounds like static, but a burst plus an F2 transition from the
/// right locus is what makes `ba`, `da` and `ga` distinguishable.
///
/// Deliberately Foundation-only: no AVFoundation, no Accelerate, so the whole
/// thing is unit-testable and portable.
struct ChantSynth {

    var sampleRate: Double = 44_100

    /// Control-rate block. 32 samples is ~0.7 ms — fine enough that moving
    /// formants glide instead of stepping, coarse enough to stay cheap.
    private let blockSize = 32

    /// Levels, all measured rather than guessed. See `Tuning` notes in the README.
    private enum Level {
        /// The lip-radiation difference `x - 0.97·x₋₁` costs about 22 dB at F1;
        /// this puts the source back at unity around 500 Hz.
        static let sourceMakeup = 13.0
        /// Stop bursts are quieter than the vowel that follows them. Setting this
        /// as an absolute amplitude instead of a fraction of the syllable peak is
        /// what made early renders spike 33 dB over the voice.
        static let burst = 0.55
        static let fricative = 0.62
        static let voiceBar = 0.10
        static let voicedBus = 1.0
        static let noiseBus = 0.5
        /// Compensates the source's downward spectral tilt so that high formants —
        /// F2 of /i/ especially — stay audible enough to carry vowel identity.
        static let tiltF2 = 0.6
        static let tiltF3 = 0.5
    }

    init(sampleRate: Double = 44_100) {
        self.sampleRate = sampleRate
    }

    // MARK: - Entry points

    static func render(chant: String,
                       voice: VoiceProfile,
                       sampleRate: Double = 44_100,
                       seed: UInt64 = 0x5EED) -> [Float] {
        ChantSynth(sampleRate: sampleRate).render(ChantParser.parse(chant), voice: voice, seed: seed)
    }

    func render(_ phrase: ChantPhrase, voice: VoiceProfile, seed: UInt64 = 0x5EED) -> [Float] {
        guard !phrase.isEmpty else { return [] }
        let notes = layout(phrase, voice: voice)
        guard let last = notes.last else { return [] }

        let totalSeconds = last.start + last.duration + 0.06
        let totalSamples = max(1, Int(totalSeconds * sampleRate))
        let frames = buildControlTrack(notes: notes, voice: voice, totalSamples: totalSamples)
        var signal = synthesize(frames: frames, voice: voice, totalSamples: totalSamples, seed: seed)
        finish(&signal, voice: voice)
        return signal
    }

    // MARK: - Layout

    private struct Note {
        var syllable: Syllable
        var start: Double
        var duration: Double
        var index: Int
        var isWordFinal: Bool
        /// 0...1 position through the phrase, used for pitch declination.
        var progress: Double
    }

    private func layout(_ phrase: ChantPhrase, voice: VoiceProfile) -> [Note] {
        let total = max(1, phrase.syllableCount)
        var notes: [Note] = []
        notes.reserveCapacity(total)

        var time = 0.0
        var index = 0
        let base = 1.0 / max(0.5, voice.tempo)

        for (wordIndex, word) in phrase.words.enumerated() {
            for (position, syllable) in word.enumerated() {
                // Swing lengthens the downbeat and clips the offbeat.
                let swing = index.isMultiple(of: 2)
                    ? 1 + voice.swing * 0.3
                    : 1 - voice.swing * 0.3
                let duration = base * syllable.lengthFactor * swing
                notes.append(Note(syllable: syllable,
                                  start: time,
                                  duration: duration,
                                  index: index,
                                  isWordFinal: position == word.count - 1,
                                  progress: Double(index) / Double(total)))
                time += duration
                index += 1
            }
            if wordIndex < phrase.words.count - 1 { time += voice.wordGap }
        }
        return notes
    }

    // MARK: - Control track

    private struct ControlFrame {
        var f0: Double = 110
        var amp: Double = 0
        var voiced: Double = 0
        var noise: Double = 0
        var f1: Double = 500, f2: Double = 1500, f3: Double = 2500
        var b1: Double = 80, b2: Double = 110, b3: Double = 170
        var noiseHz: Double = 2000, noiseQ: Double = 2
        /// Amplitude flutter depth for trills, 0...1.
        var trill: Double = 0
    }

    /// Formant positions for the consonants that have a voiced tract shape.
    private enum TractShape {
        static let lateral  = (f1: 350.0, f2: 1100.0, f3: 2600.0)   // l
        static let rhotic   = (f1: 400.0, f2: 1250.0, f3: 1700.0)   // r — the dropped F3 is the cue
        static let nasal    = (f1: 260.0, f2: 1000.0, f3: 2250.0)
        static let neutral  = (f1: 500.0, f2: 1400.0, f3: 2450.0)
    }

    /// Where F2 starts when a stop is released. Locus theory, roughly.
    private func stopLocus(_ place: Syllable.Place) -> Double {
        switch place {
        case .labial: return 750
        case .dental: return 1800
        case .velar:  return 2400
        }
    }

    private func buildControlTrack(notes: [Note], voice: VoiceProfile, totalSamples: Int) -> [ControlFrame] {
        let blockCount = totalSamples / blockSize + 2
        var frames = [ControlFrame](repeating: ControlFrame(), count: blockCount)
        let scale = max(0.5, voice.formantScale)
        let f3Lift = 0.9 + 0.3 * voice.brightness

        var carryAmp = 0.0

        for note in notes {
            let syllable = note.syllable
            let d = note.duration
            let (onsetDur, codaDur) = segmentDurations(for: syllable, noteDuration: d)
            let bodyDur = max(0.02, d - onsetDur - codaDur)

            let (vf1, vf2, vf3) = syllable.vowel.formants
            let vowel = (f1: vf1 * scale, f2: vf2 * scale, f3: vf3 * scale * f3Lift)
            let (vb1, vb2, vb3) = syllable.vowel.bandwidths

            // Where the tract starts before it opens into the vowel.
            let entry: (f1: Double, f2: Double, f3: Double)
            switch syllable.onset {
            case .liquid(let rhotic):
                entry = rhotic ? scaled(TractShape.rhotic, scale) : scaled(TractShape.lateral, scale)
            case .nasal:
                entry = scaled(TractShape.nasal, scale)
            case .trill:
                entry = scaled(TractShape.rhotic, scale)
            case .plosive(let place, _):
                entry = (f1: vowel.f1 * 0.7, f2: stopLocus(place) * scale, f3: vowel.f3)
            case .fricative(let place, _):
                entry = (f1: vowel.f1 * 0.8, f2: stopLocus(place) * scale * 0.95, f3: vowel.f3)
            case .none:
                entry = vowel
            }
            // A cluster like "tr" or "gl" adds a second, liquid-flavoured approach.
            let approach = syllable.liquidRelease ? scaled(TractShape.rhotic, scale) : entry

            let exitShape = syllable.coda ? scaled(TractShape.nasal, scale) : scaled(TractShape.neutral, scale)
            let peak = (syllable.stressed ? 1.0 : 0.8) * (0.75 + 0.25 * syllable.vowel.openness)
            let floorLevel = note.isWordFinal ? 0.0 : 0.16

            let startBlock = max(0, Int(note.start * sampleRate) / blockSize)
            let endBlock = min(blockCount - 1, Int((note.start + d) * sampleRate) / blockSize)
            guard startBlock <= endBlock else { continue }

            for block in startBlock...endBlock {
                let t = Double(block * blockSize) / sampleRate - note.start
                guard t >= 0 else { continue }
                var frame = ControlFrame()

                // --- amplitude, voicing, noise -------------------------------
                var amp = 0.0, voiced = 0.0, noise = 0.0
                var noiseHz = 2000.0, noiseQ = 2.0
                var pos = (f1: vowel.f1, f2: vowel.f2, f3: vowel.f3)
                var bw = (b1: vb1, b2: vb2, b3: vb3)

                if t < onsetDur {
                    let u = onsetDur > 0 ? t / onsetDur : 1
                    switch syllable.onset {
                    case .none:
                        amp = carryAmp + (peak - carryAmp) * u
                        voiced = 1
                        pos = entry
                    case .plosive(let place, let isVoiced):
                        // Closure, then a short burst right at the release.
                        let burstStart = 0.78
                        if u < burstStart {
                            amp = isVoiced ? peak * Level.voiceBar * (1 - u) : 0.0
                            voiced = isVoiced ? 1 : 0
                            pos = (f1: 180 * scale, f2: entry.f2, f3: entry.f3)
                            bw = (b1: 240, b2: 320, b3: 400)
                        } else {
                            let bu = (u - burstStart) / (1 - burstStart)
                            amp = peak * Level.burst * exp(-bu * 4.5)
                            noise = 1
                            voiced = isVoiced ? 0.25 : 0
                            noiseHz = place.burstHz
                            noiseQ = place.burstQ
                            pos = entry
                            // Keep the resonators damped across the release or the
                            // abrupt coefficient change rings.
                            bw = (b1: 140, b2: 200, b3: 260)
                        }
                    case .fricative(let place, let isVoiced):
                        amp = peak * Level.fricative
                            * smoothstep(min(1, u * 3))
                            * (1 - 0.25 * smoothstep(max(0, u * 2 - 1)))
                        noise = 1
                        voiced = isVoiced ? 0.4 : 0
                        noiseHz = place.burstHz * 1.15
                        noiseQ = place.burstQ * 1.6
                        pos = entry
                    case .nasal:
                        amp = carryAmp + (peak * 0.55 - carryAmp) * smoothstep(min(1, u * 2.5))
                        voiced = 1
                        pos = entry
                        bw = (b1: 190, b2: 250, b3: 320)   // nasal damping
                    case .liquid:
                        amp = carryAmp + (peak * 0.7 - carryAmp) * smoothstep(min(1, u * 2))
                        voiced = 1
                        pos = entry
                    case .trill:
                        amp = peak * 0.8
                        voiced = 1
                        pos = entry
                        frame.trill = 1
                    }
                } else if t < onsetDur + bodyDur {
                    let u = (t - onsetDur) / bodyDur
                    let attack = min(0.35, max(0.05, 0.014 / bodyDur))
                    let release = min(0.35, max(0.05, 0.026 / bodyDur))
                    let entryAmp = onsetDur > 0 ? peak * 0.6 : carryAmp

                    if u < attack {
                        amp = entryAmp + (peak - entryAmp) * smoothstep(u / attack)
                    } else if u > 1 - release {
                        let r = (u - (1 - release)) / release
                        let target = syllable.coda ? peak * 0.45 : floorLevel
                        amp = (peak * 0.88) + (target - peak * 0.88) * smoothstep(r)
                    } else {
                        amp = peak * (1 - 0.12 * (u - attack) / max(0.01, 1 - attack - release))
                    }
                    voiced = 1
                    noise = voice.breathiness * 0.5

                    // The formant glide. This is the part that sounds like language.
                    let glideSpan = syllable.liquidRelease ? 0.42 : 0.3
                    if u < glideSpan {
                        let g = smoothstep(u / glideSpan)
                        let from = syllable.liquidRelease && u < glideSpan * 0.45 ? entry : approach
                        pos = (f1: lerp(from.f1, vowel.f1, g),
                               f2: lerp(from.f2, vowel.f2, g),
                               f3: lerp(from.f3, vowel.f3, g))
                    }
                    if case .trill = syllable.onset { frame.trill = 1 }
                } else {
                    let u = codaDur > 0 ? (t - onsetDur - bodyDur) / codaDur : 1
                    amp = peak * 0.45 * (1 - smoothstep(u)) + floorLevel * smoothstep(u)
                    voiced = 1
                    let g = smoothstep(u)
                    pos = (f1: lerp(vowel.f1, exitShape.f1, g),
                           f2: lerp(vowel.f2, exitShape.f2, g),
                           f3: lerp(vowel.f3, exitShape.f3, g))
                    bw = (b1: lerp(vb1, 200, g), b2: lerp(vb2, 260, g), b3: lerp(vb3, 340, g))
                }

                // --- pitch ---------------------------------------------------
                let absoluteTime = note.start + t
                let semitone = voice.semitoneOffset(atSyllable: note.index)
                    - voice.declination * note.progress
                let vibratoRamp = min(1, t / 0.12)
                let vibrato = sin(2 * .pi * voice.vibratoRate * absoluteTime)
                    * voice.vibratoDepth * vibratoRamp
                // Stressed syllables get scooped into from below.
                let scoop = syllable.stressed ? -1.0 * exp(-t / 0.05) : 0
                frame.f0 = voice.fundamental * pow(2, (semitone + vibrato + scoop) / 12)

                frame.amp = max(0, amp)
                frame.voiced = voiced
                frame.noise = noise
                frame.f1 = pos.f1; frame.f2 = pos.f2; frame.f3 = pos.f3
                frame.b1 = bw.b1;  frame.b2 = bw.b2;  frame.b3 = bw.b3
                frame.noiseHz = noiseHz
                frame.noiseQ = noiseQ
                frames[block] = frame
                carryAmp = frame.amp
            }
        }
        return frames
    }

    private func segmentDurations(for syllable: Syllable, noteDuration d: Double) -> (onset: Double, coda: Double) {
        let onset: Double
        switch syllable.onset {
        case .none:               onset = min(0.010, d * 0.1)
        case .plosive:            onset = min(0.062, d * 0.32)
        case .fricative:          onset = min(0.085, d * 0.40)
        case .nasal:              onset = min(0.070, d * 0.33)
        case .liquid:             onset = min(0.055, d * 0.28)
        case .trill:              onset = d * 0.85
        }
        let coda = syllable.coda ? min(0.058, d * 0.24) : 0
        // Never let the consonants eat the whole syllable.
        let cap = d * 0.75
        if onset + coda > cap {
            let k = cap / (onset + coda)
            return (onset * k, coda * k)
        }
        return (onset, coda)
    }

    // MARK: - Synthesis

    private func synthesize(frames: [ControlFrame],
                            voice: VoiceProfile,
                            totalSamples: Int,
                            seed: UInt64) -> [Float] {
        var out = [Float](repeating: 0, count: totalSamples)
        var rng = DeterministicRandom(seed: seed)

        var formant1 = Biquad(sampleRate: sampleRate)
        var formant2 = Biquad(sampleRate: sampleRate)
        var formant3 = Biquad(sampleRate: sampleRate)
        var noiseBand = Biquad(sampleRate: sampleRate)

        let g2Base = 0.30 + 0.35 * voice.brightness
        let g3Base = 0.10 + 0.30 * voice.brightness
        let openQuotient = 0.55 + 0.25 * voice.breathiness
        let growl = voice.growl

        var phase = 0.0
        var previousFlow = 0.0
        var evenPeriod = true
        var trillPhase = 0.0

        for block in 0..<(totalSamples / blockSize + 1) {
            let frame = frames[min(block, frames.count - 1)]
            let next = frames[min(block + 1, frames.count - 1)]

            formant1.setBandpass(centerHz: frame.f1, bandwidthHz: frame.b1)
            formant2.setBandpass(centerHz: frame.f2, bandwidthHz: frame.b2)
            formant3.setBandpass(centerHz: frame.f3, bandwidthHz: frame.b3)
            noiseBand.setBandpass(centerHz: frame.noiseHz,
                                  bandwidthHz: max(120, frame.noiseHz / max(0.4, frame.noiseQ)))

            // Formant gains follow the formants, undoing the source tilt so that a
            // vowel with a very high F2 does not lose its identity cue.
            let reference = max(120, frame.f1)
            let g2 = g2Base * pow(frame.f2 / reference, Level.tiltF2)
            let g3 = g3Base * pow(frame.f3 / reference, Level.tiltF3)

            let start = block * blockSize
            let end = min(start + blockSize, totalSamples)
            guard start < end else { break }

            for i in start..<end {
                let u = Double(i - start) / Double(blockSize)
                let f0 = lerp(frame.f0, next.f0, u)
                let amp = lerp(frame.amp, next.amp, u)
                let voicedGain = lerp(frame.voiced, next.voiced, u)
                let noiseGain = lerp(frame.noise, next.noise, u)
                let trillDepth = lerp(frame.trill, next.trill, u)

                // Glottal flow.
                phase += f0 / sampleRate
                if phase >= 1 {
                    phase -= 1
                    evenPeriod.toggle()
                }
                // Period doubling is most of what "growl" is.
                let periodGain = (growl > 0.01 && !evenPeriod) ? 1 - 0.55 * growl : 1
                let flow = rosenberg(phase, openQuotient: openQuotient) * periodGain

                // Differentiate for the lip-radiation characteristic.
                let radiated = (flow - 0.97 * previousFlow) * Level.sourceMakeup
                previousFlow = flow

                var source = radiated + rng.nextBipolar() * voice.breathiness * 0.18
                source *= voicedGain

                var voicedOut = formant1.process(source)
                voicedOut += formant2.process(source) * g2
                voicedOut += formant3.process(source) * g3

                let noiseOut = noiseBand.process(rng.nextBipolar()) * noiseGain

                var sample = voicedOut * Level.voicedBus + noiseOut * Level.noiseBus

                if trillDepth > 0.01 {
                    trillPhase += 27.0 / sampleRate           // alveolar trill rate
                    if trillPhase >= 1 { trillPhase -= 1 }
                    let flutter = 0.45 + 0.55 * (0.5 - 0.5 * cos(2 * .pi * trillPhase))
                    sample *= 1 - trillDepth + trillDepth * flutter
                }

                out[i] = Float(sample * amp)
            }
        }
        return out
    }

    /// Rosenberg glottal flow pulse: a smooth rise, a faster fall, then closure.
    @inline(__always)
    private func rosenberg(_ phase: Double, openQuotient: Double) -> Double {
        let oq = min(0.92, max(0.35, openQuotient))
        let peak = oq * 0.72
        if phase < peak {
            let x = phase / peak
            return 3 * x * x - 2 * x * x * x
        } else if phase < oq {
            let x = (phase - peak) / (oq - peak)
            return 1 - x * x
        }
        return 0
    }

    // MARK: - Output shaping

    private func finish(_ signal: inout [Float], voice: VoiceProfile) {
        guard !signal.isEmpty else { return }

        // The differentiator leaves low-frequency junk behind.
        var highpass = Biquad(sampleRate: sampleRate)
        highpass.setHighpass(cutoffHz: 75)
        var tame = Biquad(sampleRate: sampleRate)
        tame.setLowpass(cutoffHz: min(9_500, sampleRate * 0.44))

        let drive = 1 + 3 * voice.growl
        let normalizer = tanh(drive)

        for i in signal.indices {
            var x = highpass.process(Double(signal[i]))
            x = tanh(x * drive) / normalizer
            signal[i] = Float(tame.process(x))
        }

        // Normalise to a consistent headroom so no character is quieter than
        // another — this is an alarm, every voice has to land at the same level.
        var peak: Float = 0
        for sample in signal { peak = max(peak, abs(sample)) }
        if peak > 1e-6 {
            let gain = 0.89 / peak
            for i in signal.indices { signal[i] *= gain }
        }

        applyFade(&signal, seconds: 0.004, atStart: true)
        applyFade(&signal, seconds: 0.015, atStart: false)
    }

    private func applyFade(_ signal: inout [Float], seconds: Double, atStart: Bool) {
        let count = min(signal.count, Int(seconds * sampleRate))
        guard count > 1 else { return }
        for i in 0..<count {
            let gain = Float(Double(i) / Double(count - 1))
            let index = atStart ? i : signal.count - 1 - i
            signal[index] *= gain
        }
    }
}

// MARK: - Small math helpers

@inline(__always) func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

@inline(__always) func smoothstep(_ t: Double) -> Double {
    let x = min(1, max(0, t))
    return x * x * (3 - 2 * x)
}

@inline(__always)
private func scaled(_ shape: (f1: Double, f2: Double, f3: Double), _ k: Double)
    -> (f1: Double, f2: Double, f3: Double) {
    (f1: shape.f1 * k, f2: shape.f2 * k, f3: shape.f3 * k)
}
