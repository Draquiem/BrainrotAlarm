import Foundation

// MARK: - AlarmKit path (iOS 26+)
//
// AlarmKit is the only way a third-party app can ring a genuine alarm: it breaks
// through silent mode and Focus, survives the app being terminated, and is not
// bound by the 30-second notification-sound cap or the 64-notification budget that
// `NotificationScheduler` has to work around.
//
// It is behind the `BRAINROT_ALARMKIT` compilation condition rather than a plain
// availability check, because this file was written without an iOS 26 SDK to
// compile against and the exact spelling of these types has not been verified.
// Turn it on once you have checked it in Xcode:
//
//     Build Settings → Swift Compiler - Custom Flags
//       → Active Compilation Conditions → add BRAINROT_ALARMKIT
//
// and add `NSAlarmKitUsageDescription` to the Info.plist keys. Until then the app
// builds and runs on the notification path, which needs no entitlement at all.

#if BRAINROT_ALARMKIT
import AlarmKit
import AppIntents
import SwiftUI

/// Attached to each scheduled alarm so the Live Activity and the stop intent can
/// find out which character is chanting.
struct BrainrotAlarmMetadata: AlarmMetadata {
    let alarmID: String
    let characterID: String
    let firedAt: Date
}

@available(iOS 26.0, *)
actor AlarmKitScheduler: AlarmScheduling {

    private let manager = AlarmManager.shared

    func requestAuthorization() async {
        do {
            _ = try await manager.requestAuthorization()
        } catch {
            print("[alarmkit] authorization failed: \(error)")
        }
    }

    func cancelAll() async {
        for alarm in (try? manager.alarms) ?? [] {
            try? manager.cancel(id: alarm.id)
        }
        ChantSoundLibrary.prune(keeping: [])
    }

    func reschedule(alarms: [AlarmItem]) async {
        await cancelAll()

        var soundsInUse: Set<String> = []

        for alarm in alarms where alarm.isEnabled {
            guard let fireDate = alarm.nextFireDate() else { continue }
            let character = AlarmCasting.character(for: alarm, firingAt: fireDate)
            guard let soundName = ChantSoundLibrary.ensureSoundFile(for: character) else { continue }
            soundsInUse.insert(soundName)

            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Alarm" : alarm.label),
                stopButton: AlarmButton(text: "Identify it",
                                        textColor: .white,
                                        systemImageName: "waveform.badge.magnifyingglass"))

            let attributes = AlarmAttributes(
                presentation: AlarmPresentation(alert: alert),
                metadata: BrainrotAlarmMetadata(alarmID: alarm.id.uuidString,
                                                characterID: character.id,
                                                firedAt: fireDate),
                tintColor: Color(hex: character.art.palette.accent))

            let schedule = makeSchedule(for: alarm)
            let configuration = AlarmManager.AlarmConfiguration(
                schedule: schedule,
                attributes: attributes,
                stopIntent: OpenChallengeIntent(alarmID: alarm.id.uuidString,
                                                characterID: character.id),
                sound: .named(soundName))

            do {
                try await manager.schedule(id: alarm.id, configuration: configuration)
            } catch {
                print("[alarmkit] could not schedule \(alarm.id): \(error)")
            }
        }

        ChantSoundLibrary.prune(keeping: soundsInUse)
    }

    private func makeSchedule(for alarm: AlarmItem) -> Alarm.Schedule {
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.repeatDays.isEmpty
            ? .never
            : .weekly(alarm.repeatDays.sorted().compactMap(Locale.Weekday.init))
        return .relative(.init(time: time, repeats: recurrence))
    }
}

private extension Locale.Weekday {
    init?(_ day: Weekday) {
        switch day {
        case .sunday: self = .sunday
        case .monday: self = .monday
        case .tuesday: self = .tuesday
        case .wednesday: self = .wednesday
        case .thursday: self = .thursday
        case .friday: self = .friday
        case .saturday: self = .saturday
        }
    }
}
#endif
