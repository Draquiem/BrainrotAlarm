import AVFoundation

/// Writes rendered chants into `Library/Sounds` so notifications can use them.
///
/// `UNNotificationSound(named:)` only accepts a file in the bundle or in
/// `Library/Sounds`, and this app has no audio in its bundle — every sound is
/// synthesised. So the scheduler renders whatever characters it is about to need,
/// drops them on disk, and prunes the rest.
///
/// Two hard limits from iOS, both of which this respects:
///   * over 30 seconds and the system silently substitutes the default sound;
///   * the format must be uncompressed PCM in caf/aiff/wav.
enum ChantSoundLibrary {

    /// Kept under the 30 s cliff with room to spare.
    static let maximumDuration: Double = 28
    private static let sampleRate: Double = 44_100
    private static let prefix = "brainrot-"

    static func soundFileName(for character: BrainrotCharacter) -> String {
        "\(prefix)\(character.id).caf"
    }

    private static var soundsDirectory: URL? {
        guard let library = try? FileManager.default.url(for: .libraryDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true) else { return nil }
        let directory = library.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// Renders the chant, loops it up to the duration cap, and writes it out.
    /// Returns the file name to hand to `UNNotificationSound`, or nil on failure.
    @discardableResult
    static func ensureSoundFile(for character: BrainrotCharacter) -> String? {
        // A bundled recording can be a notification sound directly, provided it is
        // uncompressed and under the 30-second cap. AssetLibrary checks both.
        if let bundled = AssetLibrary.notificationSoundName(for: character.id) {
            return bundled
        }
        guard let directory = soundsDirectory else { return nil }
        let name = soundFileName(for: character)
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return name }

        let seed = character.id.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        let chant = ChantSynth.render(chant: character.chant, voice: character.voice,
                                      sampleRate: sampleRate, seed: seed)
        guard !chant.isEmpty else { return nil }

        let gap = Int(0.45 * sampleRate)
        let unit = chant.count + gap
        let repeats = max(1, Int(maximumDuration * sampleRate) / unit)
        var samples = [Float]()
        samples.reserveCapacity(unit * repeats)
        for _ in 0..<repeats {
            samples.append(contentsOf: chant)
            samples.append(contentsOf: [Float](repeating: 0, count: gap))
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buffer.floatChannelData?[0] else { return nil }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { source in
                channel.update(from: source.baseAddress!, count: samples.count)
            }
            try file.write(from: buffer)
            return name
        } catch {
            print("[sound] could not write \(name): \(error)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Deletes rendered chants that no scheduled alarm needs any more.
    static func prune(keeping keep: Set<String>) {
        guard let directory = soundsDirectory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return }
        for file in files where file.hasPrefix(prefix) && !keep.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }
}
