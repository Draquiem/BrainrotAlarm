import Foundation
import UserNotifications

/// Puts an alarm back a few minutes.
///
/// Snoozing is capped rather than blocked: you get `maxSnoozes` free passes, and
/// after that the only way out is the challenge. Making snooze itself require the
/// puzzle would just mean solving it and going back to sleep anyway.
enum SnoozeScheduler {

    static func schedule(alarm: AlarmItem, minutes: Int) async {
        guard minutes > 0 else { return }
        let fireDate = Date().addingTimeInterval(Double(minutes) * 60)
        let character = AlarmCasting.character(for: alarm, firingAt: fireDate)
        let soundName = ChantSoundLibrary.ensureSoundFile(for: character)

        let center = UNUserNotificationCenter.current()
        // A short chain so a snooze nags as persistently as the original.
        for step in 0..<6 {
            let content = UNMutableNotificationContent()
            content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
            content.body = step == 0 ? "Snooze is over." : "Still going."
            content.sound = soundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) }
                ?? .defaultCritical
            content.interruptionLevel = .timeSensitive
            content.userInfo = [
                "alarmID": alarm.id.uuidString,
                "characterID": character.id,
                "firedAt": fireDate.timeIntervalSince1970
            ]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireDate.timeIntervalSinceNow + Double(step) * 30),
                repeats: false)
            let request = UNNotificationRequest(
                identifier: "snooze|\(alarm.id.uuidString)|\(Int(fireDate.timeIntervalSince1970))|\(step)",
                content: content,
                trigger: trigger)
            try? await center.add(request)
        }
    }
}
