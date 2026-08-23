import Foundation

/// Direct-form-I biquad, coefficients from the RBJ audio EQ cookbook.
///
/// Used three times per voice as the resonators that turn a buzzy glottal pulse
/// into a vowel, plus once more to colour consonant noise bursts.
struct Biquad {
    private var b0: Double = 1, b1: Double = 0, b2: Double = 0
    private var a1: Double = 0, a2: Double = 0
    private var x1: Double = 0, x2: Double = 0
    private var y1: Double = 0, y2: Double = 0

    let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Constant 0 dB peak-gain bandpass — the right shape for a formant, because
    /// the peak stays put as the bandwidth changes.
    mutating func setBandpass(centerHz: Double, bandwidthHz: Double) {
        let f = clampFrequency(centerHz)
        let q = max(0.35, f / max(20, bandwidthHz))
        let w0 = 2 * Double.pi * f / sampleRate
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        b0 = alpha / a0
        b1 = 0
        b2 = -alpha / a0
        a1 = (-2 * cos(w0)) / a0
        a2 = (1 - alpha) / a0
    }

    mutating func setLowpass(cutoffHz: Double, q: Double = 0.707) {
        let f = clampFrequency(cutoffHz)
        let w0 = 2 * Double.pi * f / sampleRate
        let alpha = sin(w0) / (2 * max(0.1, q))
        let cosw = cos(w0)
        let a0 = 1 + alpha
        b0 = ((1 - cosw) / 2) / a0
        b1 = (1 - cosw) / a0
        b2 = b0
        a1 = (-2 * cosw) / a0
        a2 = (1 - alpha) / a0
    }

    mutating func setHighpass(cutoffHz: Double, q: Double = 0.707) {
        let f = clampFrequency(cutoffHz)
        let w0 = 2 * Double.pi * f / sampleRate
        let alpha = sin(w0) / (2 * max(0.1, q))
        let cosw = cos(w0)
        let a0 = 1 + alpha
        b0 = ((1 + cosw) / 2) / a0
        b1 = -(1 + cosw) / a0
        b2 = b0
        a1 = (-2 * cosw) / a0
        a2 = (1 - alpha) / a0
    }

    @inline(__always)
    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }

    mutating func reset() {
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
    }

    /// Keeps the bilinear transform away from Nyquist, where `tan` blows up.
    private func clampFrequency(_ hz: Double) -> Double {
        min(max(20, hz), sampleRate * 0.45)
    }
}

/// Small deterministic PRNG so a given character always renders byte-identical
/// audio — the tests depend on it, and so does caching by character id.
struct DeterministicRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x1234_5678_9ABC_DEF0
        if state == 0 { state = 0x853C_49E6_748F_EA9B }
    }

    @inline(__always)
    mutating func nextUInt64() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545_F491_4F6C_DD1D
    }

    /// Uniform in -1...1.
    @inline(__always)
    mutating func nextBipolar() -> Double {
        let bits = nextUInt64() >> 11              // 53 significant bits
        return (Double(bits) * (1.0 / 9_007_199_254_740_992.0)) * 2 - 1
    }
}
