import Foundation
import UserNotifications

/// Schedules alarms as local notifications.
///
/// This is the path that works on every iOS version the app supports, and it has
/// two constraints worth knowing about:
///
/// * a notification sound is capped at 30 seconds, so one notification cannot ring
///   for long. The workaround is a *chain* — the same alarm scheduled every 30
///   seconds for a few minutes, so it keeps nagging until you deal with it;
/// * iOS only holds 64 pending notifications per app, so the chain length is
///   budgeted across however many alarms are switched on rather than fixed.
///
/// See `AlarmKitScheduler` for the iOS 26 path, which has neither limitation.
actor NotificationScheduler: AlarmScheduling {

    private let center = UNUserNotificationCenter.current()

    /// 64 is the hard system cap; leave room for anything else that shows up.
    private let pendingBudget = 58
    private let chainInterval: TimeInterval = 30
    private let maxChainLength = 12
    private let minChainLength = 3
    /// Occurrences scheduled ahead for a repeating alarm. Two is enough — the app
    /// reschedules whenever it is opened or an alarm is dismissed.
    private let occurrencesPerRepeatingAlarm = 2

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[notify] authorization failed: \(error)")
        }
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        ChantSoundLibrary.prune(keeping: [])
    }

    func reschedule(alarms: [AlarmItem]) async {
        center.removeAllPendingNotificationRequests()

        let active = alarms.filter(\.isEnabled)
        guard !active.isEmpty else {
            ChantSoundLibrary.prune(keeping: [])
            return
        }

        // Work out every occurrence first so the chain length can be budgeted.
        var occurrences: [(alarm: AlarmItem, date: Date)] = []
        for alarm in active {
            let limit = alarm.isRepeating ? occurrencesPerRepeatingAlarm : 1
            for date in AlarmCasting.upcomingFireDates(for: alarm, limit: limit) {
                occurrences.append((alarm, date))
            }
        }
        guard !occurrences.isEmpty else { return }

        let chainLength = min(maxChainLength,
                              max(minChainLength, pendingBudget / occurrences.count))

        var soundsInUse: Set<String> = []
        let calendar = Calendar.current

        for (alarm, date) in occurrences {
            let character = AlarmCasting.character(for: alarm, firingAt: date)
            let soundName = ChantSoundLibrary.ensureSoundFile(for: character)
            if let soundName { soundsInUse.insert(soundName) }

            for step in 0..<chainLength {
                let fireDate = date.addingTimeInterval(chainInterval * Double(step))
                guard fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
                // Never name the character here — that is the answer.
                content.body = step == 0
                    ? "Something is chanting at you. Open up and point at it."
                    : "It has not stopped chanting."
                content.sound = soundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) }
                    ?? .defaultCritical
                content.interruptionLevel = .timeSensitive
                content.userInfo = [
                    "alarmID": alarm.id.uuidString,
                    "characterID": character.id,
                    "firedAt": date.timeIntervalSince1970
                ]
                content.categoryIdentifier = NotificationScheduler.categoryIdentifier

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: fireDate)
                let request = UNNotificationRequest(
                    identifier: "\(alarm.id.uuidString)|\(Int(date.timeIntervalSince1970))|\(step)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))

                do {
                    try await center.add(request)
                } catch {
                    print("[notify] could not schedule \(request.identifier): \(error)")
                }
            }
        }

        ChantSoundLibrary.prune(keeping: soundsInUse)
    }

    static let categoryIdentifier = "BRAINROT_ALARM"
}
