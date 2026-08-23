import Foundation

enum Weekday: Int, CaseIterable, Codable, Identifiable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    /// Single letter for the repeat picker.
    var initial: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]

    static func < (a: Weekday, b: Weekday) -> Bool { a.rawValue < b.rawValue }
}

extension BrainrotCharacter.Tier: Codable {}

/// One alarm.
struct AlarmItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String = "Alarm"
    var hour: Int = 7
    var minute: Int = 0
    var repeatDays: Set<Weekday> = []
    var isEnabled: Bool = true
    var difficulty: Difficulty = .standard
    /// How obscure the roster is allowed to get for this alarm.
    var tierCeiling: BrainrotCharacter.Tier = .core
    /// 0 disables snoozing entirely.
    var snoozeMinutes: Int = 9
    var maxSnoozes: Int = 2
    var hapticsEnabled: Bool = true
    /// Ring this specific character every time instead of drawing at random.
    /// The chant still has to be matched to the picture — you just know which.
    var pinnedCharacterID: String?

    var timeComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    var isRepeating: Bool { !repeatDays.isEmpty }

    var repeatDescription: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays == Weekday.weekdays { return "Weekdays" }
        if repeatDays == Weekday.weekend { return "Weekends" }
        if repeatDays.count == 7 { return "Every day" }
        return repeatDays.sorted().map(\.shortName).joined(separator: " ")
    }

    func formattedTime(locale: Locale = .current) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }

    /// Next time this alarm should ring, or nil if it is off.
    func nextFireDate(after reference: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isEnabled else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0

        if repeatDays.isEmpty {
            return calendar.nextDate(after: reference, matching: components,
                                     matchingPolicy: .nextTime, direction: .forward)
        }
        return repeatDays.compactMap { day -> Date? in
            var dayComponents = components
            dayComponents.weekday = day.rawValue
            return calendar.nextDate(after: reference, matching: dayComponents,
                                     matchingPolicy: .nextTime, direction: .forward)
        }.min()
    }

    /// The roster this alarm draws from. A pinned character only fixes the *answer*;
    /// the decoys still come from the whole tier pool, so the grid stays full.
    func pool() -> [BrainrotCharacter] {
        BrainrotCatalog.characters(upTo: tierCeiling)
    }
}

/// One dismissal, for the stats screen.
struct WakeRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var alarmID: UUID
    var characterID: String
    var difficulty: Difficulty
    /// Wall-clock seconds from the alarm firing to the last correct tap.
    var secondsToDismiss: Double
    var misses: Int
    var snoozes: Int
}
