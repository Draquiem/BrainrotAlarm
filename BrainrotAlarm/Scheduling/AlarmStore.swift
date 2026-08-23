import Foundation
import Combine

/// Owns the alarms and the wake log, persists them, and keeps the scheduler in
/// step whenever either changes.
@MainActor
final class AlarmStore: ObservableObject {

    @Published private(set) var alarms: [AlarmItem] = []
    @Published private(set) var wakeLog: [WakeRecord] = []
    /// Set when the alarm the user is currently being yelled at by is known.
    @Published var ringing: RingingContext?

    private let scheduler: AlarmScheduling
    private let fileURL: URL
    private let logURL: URL

    init(scheduler: AlarmScheduling) {
        self.scheduler = scheduler
        let directory = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        fileURL = directory.appendingPathComponent("alarms.json")
        logURL = directory.appendingPathComponent("wake-log.json")
        load()
    }

    // MARK: - Mutations

    func add(_ alarm: AlarmItem) {
        alarms.append(alarm)
        sortAlarms()
        persist()
        Task { await reschedule() }
    }

    func update(_ alarm: AlarmItem) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
        sortAlarms()
        persist()
        Task { await reschedule() }
    }

    func delete(_ alarm: AlarmItem) {
        alarms.removeAll { $0.id == alarm.id }
        persist()
        Task { await reschedule() }
    }

    func delete(atOffsets offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        persist()
        Task { await reschedule() }
    }

    func setEnabled(_ enabled: Bool, for alarm: AlarmItem) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled = enabled
        persist()
        Task { await reschedule() }
    }

    func alarm(id: UUID) -> AlarmItem? { alarms.first { $0.id == id } }

    // MARK: - Wake log

    func record(_ record: WakeRecord) {
        wakeLog.insert(record, at: 0)
        // A month of history is plenty for the stats screen.
        if wakeLog.count > 200 { wakeLog.removeLast(wakeLog.count - 200) }
        persistLog()
    }

    var currentStreak: Int {
        WakeStreak.length(of: wakeLog)
    }

    // MARK: - Scheduling

    func reschedule() async {
        await scheduler.reschedule(alarms: alarms)
    }

    func requestPermissions() async {
        await scheduler.requestAuthorization()
    }

    // MARK: - Persistence

    private func sortAlarms() {
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([AlarmItem].self, from: data) {
            alarms = decoded
            sortAlarms()
        } else {
            alarms = AlarmStore.starterAlarms
        }
        if let data = try? Data(contentsOf: logURL),
           let decoded = try? decoder.decode([WakeRecord].self, from: data) {
            wakeLog = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(alarms) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func persistLog() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(wakeLog) else { return }
        try? data.write(to: logURL, options: .atomic)
    }

    /// What a brand new install starts with.
    private static var starterAlarms: [AlarmItem] {
        [AlarmItem(label: "Wake up", hour: 6, minute: 45,
                   repeatDays: Weekday.weekdays, isEnabled: false,
                   difficulty: .standard, tierCeiling: .starter)]
    }
}

/// Everything the ringing screen needs to know.
struct RingingContext: Identifiable, Equatable {
    let alarm: AlarmItem
    let firedAt: Date
    /// A rehearsal or a practice round: behaves identically, but is kept out of
    /// the wake log so it cannot inflate a streak.
    var isRehearsal: Bool = false

    /// Derived, not a fresh `UUID`.
    ///
    /// `RootView` rebuilds this value every time it evaluates its body, and
    /// `fullScreenCover(item:)` keys off `id` — a random one would change on every
    /// pass and tear the ringing screen down and back up underneath the user.
    var id: String {
        "\(alarm.id.uuidString)|\(Int(firedAt.timeIntervalSince1970))|\(isRehearsal)"
    }
}

/// Consecutive days ending today (or yesterday) with at least one logged wake-up.
///
/// Pulled out of the store as a plain function so the calendar arithmetic can be
/// tested against fixed dates instead of whatever today happens to be.
enum WakeStreak {
    static func length(of records: [WakeRecord],
                       asOf today: Date = Date(),
                       calendar: Calendar = .current) -> Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: today)
        // Not having woken up *yet* today should not break yesterday's streak.
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
