import Foundation

protocol AlarmScheduling: Sendable {
    func requestAuthorization() async
    func reschedule(alarms: [AlarmItem]) async
    func cancelAll() async
}

/// Decides which character rings for a given alarm at a given time.
///
/// Deterministic on purpose: the scheduler needs to know the answer when it writes
/// the notification sound, and the app needs to arrive at the same answer when it
/// opens — possibly from a cold launch, with no shared state between them. Hashing
/// the alarm id and the fire time gets both sides to the same character with
/// nothing persisted.
enum AlarmCasting {

    static func character(for alarm: AlarmItem, firingAt date: Date) -> BrainrotCharacter {
        let pool = alarm.pool()
        guard !pool.isEmpty else { return BrainrotCatalog.all[0] }

        if let pinned = alarm.pinnedCharacterID,
           let character = BrainrotCatalog.character(id: pinned) {
            return character
        }

        // Minute resolution: the notification chain fires every 30 s and every link
        // has to name the same character.
        let slot = UInt64(bitPattern: Int64(date.timeIntervalSince1970 / 60))

        var hash = UInt64(5381)
        for byte in alarm.id.uuidString.utf8 { hash = (hash &* 33) &+ UInt64(byte) }

        // The slot has to be avalanched, not just added. A daily alarm advances the
        // slot by exactly 1440, and 1440 is a multiple of the roster size, so a
        // plain `hash + slot` picks the identical character every single morning.
        // This is the murmur3 finaliser.
        var mixed = slot
        mixed ^= mixed >> 33
        mixed = mixed &* 0xff51_afd7_ed55_8ccd
        mixed ^= mixed >> 33
        mixed = mixed &* 0xc4ce_b9fe_1a85_ec53
        mixed ^= mixed >> 33

        return pool[Int((hash ^ mixed) % UInt64(pool.count))]
    }

    /// The next few times an alarm will go off.
    static func upcomingFireDates(for alarm: AlarmItem,
                                  limit: Int,
                                  after reference: Date = Date(),
                                  calendar: Calendar = .current) -> [Date] {
        guard alarm.isEnabled, limit > 0 else { return [] }
        var dates: [Date] = []
        var cursor = reference
        while dates.count < limit, let next = alarm.nextFireDate(after: cursor, calendar: calendar) {
            dates.append(next)
            cursor = next
            if !alarm.isRepeating { break }
        }
        return dates
    }
}
