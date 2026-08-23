import AVFoundation
import Combine

/// Renders chants on demand and plays them through `AVAudioEngine`.
///
/// Nothing is bundled: every sound in the app comes out of `ChantSynth` at
/// runtime and is cached per character. A three-second chant is roughly 130 000
/// samples through four biquads, which takes single-digit milliseconds, so the
/// first play of a character renders on a background task and every play after
/// that is instant.
@MainActor
final class AlarmAudioEngine: ObservableObject {

    static let shared = AlarmAudioEngine()

    @Published private(set) var isRinging = false
    @Published private(set) var nowPlaying: BrainrotCharacter?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var rampTimer: Timer?
    private var isConfigured = false

    /// Volume the alarm starts at before ramping up. Loud enough to wake you,
    /// quiet enough not to launch you out of bed.
    private let startVolume: Float = 0.45
    private let rampSeconds: Double = 25

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    // MARK: - Session

    /// `.playback` is what lets an alarm be heard with the ring/silent switch set
    /// to silent. Without it the whole app is decorative.
    func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            print("[audio] could not activate session: \(error)")
        }
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureEngineIfNeeded() {
        guard !isConfigured else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isConfigured = true
    }

    private func startEngineIfNeeded() {
        configureEngineIfNeeded()
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("[audio] engine failed to start: \(error)")
        }
    }

    // MARK: - Playback

    /// Starts the alarm looping until `stop()` is called.
    func startRinging(_ character: BrainrotCharacter) async {
        activateSession()
        startEngineIfNeeded()
        guard let buffer = await buffer(for: character, trailingSilence: 0.45) else { return }

        player.stop()
        player.volume = startVolume
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        isRinging = true
        nowPlaying = character
        beginVolumeRamp()
    }

    /// Plays a chant once — used by the practice screen and the character list.
    func preview(_ character: BrainrotCharacter) async {
        guard !isRinging else { return }
        activateSession()
        startEngineIfNeeded()
        guard let buffer = await buffer(for: character, trailingSilence: 0.1) else { return }
        player.stop()
        player.volume = 1
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
        nowPlaying = character
    }

    /// Replays the current chant from the top without restarting the ramp.
    func replayCurrent() async {
        guard let character = nowPlaying, isRinging else { return }
        guard let buffer = await buffer(for: character, trailingSilence: 0.45) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }

    func stop() {
        rampTimer?.invalidate()
        rampTimer = nil
        player.stop()
        if engine.isRunning { engine.pause() }
        isRinging = false
        nowPlaying = nil
    }

    private func beginVolumeRamp() {
        rampTimer?.invalidate()
        let start = Date()
        rampTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                let progress = min(1, Date().timeIntervalSince(start) / self.rampSeconds)
                self.player.volume = self.startVolume + (1 - self.startVolume) * Float(progress)
                if progress >= 1 { timer.invalidate() }
            }
        }
    }

    // MARK: - Rendering

    private func buffer(for character: BrainrotCharacter, trailingSilence: Double) async -> AVAudioPCMBuffer? {
        let key = "\(character.id)-\(trailingSilence)"
        if let cached = cache[key] { return cached }

        let rate = sampleRate
        let chant = character.chant
        let voice = character.voice
        let seed = AlarmAudioEngine.seed(for: character.id)

        // Render off the main actor; the synth is pure and holds no shared state.
        let samples: [Float] = await Task.detached(priority: .userInitiated) {
            ChantSynth.render(chant: chant, voice: voice, sampleRate: rate, seed: seed)
        }.value

        guard !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
        else { return nil }

        let silenceFrames = Int(trailingSilence * rate)
        let total = samples.count + silenceFrames
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(total)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(total)
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        // Buffer memory is not guaranteed zeroed, so clear the gap explicitly.
        channel.advanced(by: samples.count).update(repeating: 0, count: silenceFrames)

        cache[key] = buffer
        return buffer
    }

    /// Stable per-character seed so a character always sounds byte-identical.
    private static func seed(for id: String) -> UInt64 {
        id.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
    }

    // MARK: - Interruptions

    @objc private nonisolated func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        Task { @MainActor in
            switch type {
            case .began:
                // A call takes the session; hold the ringing flag so we can resume.
                self.player.pause()
            case .ended:
                guard self.isRinging else { return }
                self.activateSession()
                self.startEngineIfNeeded()
                self.player.play()
            @unknown default:
                break
            }
        }
    }
}
