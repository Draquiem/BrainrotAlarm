import AppIntents
import Foundation

/// Run when the alarm's stop button is pressed.
///
/// It does not actually stop anything — it hands the alarm off to the app so the
/// matching challenge can start. That is the whole design: the system alarm UI
/// only gets you as far as opening the app, and the chant keeps going until you
/// have identified who is chanting.
struct OpenChallengeIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Identify the chant"
    static var description = IntentDescription("Opens Brainrot Alarm so you can pick the right character.")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Alarm")
    var alarmID: String

    @Parameter(title: "Character")
    var characterID: String

    init() {
        alarmID = ""
        characterID = ""
    }

    init(alarmID: String, characterID: String) {
        self.alarmID = alarmID
        self.characterID = characterID
    }

    func perform() async throws -> some IntentResult {
        await PendingAlarmHandoff.shared.set(alarmID: alarmID, characterID: characterID)
        return .result()
    }
}

/// A tiny mailbox between the intent and the app.
///
/// The intent may run in a separate process from the UI, so it drops the details
/// in shared defaults and the app picks them up when it becomes active.
actor PendingAlarmHandoff {
    static let shared = PendingAlarmHandoff()

    private let defaults = UserDefaults.standard
    private let alarmKey = "pendingAlarmID"
    private let characterKey = "pendingCharacterID"
    private let timeKey = "pendingFiredAt"

    func set(alarmID: String, characterID: String, firedAt: Date = Date()) {
        defaults.set(alarmID, forKey: alarmKey)
        defaults.set(characterID, forKey: characterKey)
        defaults.set(firedAt.timeIntervalSince1970, forKey: timeKey)
    }

    func take() -> (alarmID: UUID, characterID: String, firedAt: Date)? {
        guard let alarmString = defaults.string(forKey: alarmKey),
              let alarmID = UUID(uuidString: alarmString),
              let characterID = defaults.string(forKey: characterKey) else { return nil }
        let firedAt = Date(timeIntervalSince1970: defaults.double(forKey: timeKey))
        defaults.removeObject(forKey: alarmKey)
        defaults.removeObject(forKey: characterKey)
        defaults.removeObject(forKey: timeKey)
        return (alarmID, characterID, firedAt)
    }
}
