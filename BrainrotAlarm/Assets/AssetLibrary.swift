import UIKit
import AVFoundation

/// Finds hand-made artwork and recordings for a character, if any exist.
///
/// Every character still has a procedural drawing and a synthesised chant, and
/// those remain the fallback. Drop `tralalero.png` into `Assets/images/` or
/// `tralalero.wav` into `Assets/audio/` — named by the character's `id` — and the
/// app uses it instead. Nothing else has to change: no Xcode edit, no catalogue
/// edit, no rebuild of anything but the app.
///
/// The point of the fallback is that the roster works while it is half-finished.
/// Ship three real recordings and the other twenty-one still ring.
enum AssetLibrary {

    /// Extensions checked for each kind, in preference order.
    private static let imageExtensions = ["png", "jpg", "jpeg", "heic"]
    private static let audioExtensions = ["wav", "caf", "aiff", "m4a", "mp3"]

    private static var imageCache: [String: UIImage] = [:]
    private static let cacheLock = NSLock()

    // MARK: - Images

    /// Bundled artwork for a character, or nil to fall back to `CreatureRenderer`.
    static func image(for id: String) -> UIImage? {
        cacheLock.lock()
        if let cached = imageCache[id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let url = url(for: id, extensions: imageExtensions, subdirectory: "images"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }

        cacheLock.lock()
        imageCache[id] = image
        cacheLock.unlock()
        return image
    }

    static func hasImage(for id: String) -> Bool { image(for: id) != nil }

    // MARK: - Audio

    /// Bundled recording for a character, or nil to fall back to `ChantSynth`.
    static func audioURL(for id: String) -> URL? {
        url(for: id, extensions: audioExtensions, subdirectory: "audio")
    }

    static func hasAudio(for id: String) -> Bool { audioURL(for: id) != nil }

    /// Decodes a bundled recording into a buffer the alarm engine can loop.
    ///
    /// Returns nil for anything that will not decode, which sends the caller back
    /// to the synthesiser rather than leaving the alarm silent.
    static func audioBuffer(for id: String, trailingSilence: Double = 0.45) -> AVAudioPCMBuffer? {
        guard let url = audioURL(for: id) else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0 else { return nil }

            let padding = AVAudioFrameCount(trailingSilence * format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                frameCapacity: frames + padding) else { return nil }
            try file.read(into: buffer, frameCount: frames)
            buffer.frameLength = frames + padding

            // Zero the gap; buffer memory is not guaranteed clean.
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    channels[channel].advanced(by: Int(frames))
                        .update(repeating: 0, count: Int(padding))
                }
            }
            return buffer
        } catch {
            print("[assets] could not decode audio for \(id): \(error)")
            return nil
        }
    }

    /// Name to hand `UNNotificationSound`, if a bundled file can serve as one.
    ///
    /// iOS only accepts uncompressed PCM here and caps it at 30 seconds, so an
    /// `.mp3` or a four-minute `.wav` is rejected — those fall back to a rendered
    /// chant instead of silently playing the default ping.
    static func notificationSoundName(for id: String) -> String? {
        guard let url = audioURL(for: id) else { return nil }
        let ext = url.pathExtension.lowercased()
        guard ["wav", "caf", "aiff", "aif"].contains(ext) else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let seconds = Double(file.length) / file.fileFormat.sampleRate
        guard seconds > 0, seconds <= 30 else { return nil }
        return url.lastPathComponent
    }

    // MARK: - Lookup

    /// Xcode flattens loose resources into the bundle root, so that is the case
    /// that actually fires. The subdirectory lookup is kept for the folder-
    /// reference layout, where the path survives.
    private static func url(for id: String, extensions: [String], subdirectory: String) -> URL? {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: id, withExtension: ext) {
                return url
            }
            if let url = Bundle.main.url(forResource: id, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    // MARK: - Diagnostics

    /// What is present and what is still missing, for the settings screen.
    static func inventory() -> (images: Int, audio: Int, total: Int, missing: [String]) {
        var images = 0, audio = 0
        var missing: [String] = []
        for character in BrainrotCatalog.all {
            let hasImage = hasImage(for: character.id)
            let hasAudio = hasAudio(for: character.id)
            if hasImage { images += 1 }
            if hasAudio { audio += 1 }
            if !hasImage || !hasAudio { missing.append(character.id) }
        }
        return (images, audio, BrainrotCatalog.all.count, missing)
    }
}
