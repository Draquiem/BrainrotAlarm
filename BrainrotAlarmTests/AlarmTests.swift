import XCTest
@testable import BrainrotAlarm

final class AlarmItemTests: XCTestCase {

    /// Fixed calendar so these do not depend on where the machine thinks it is.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    func testOneShotLaterToday() {
        let alarm = AlarmItem(hour: 7, minute: 30)
        let now = date(2026, 3, 10, 6, 0)
        XCTAssertEqual(alarm.nextFireDate(after: now, calendar: calendar),
                       date(2026, 3, 10, 7, 30))
    }

    func testOneShotRollsToTomorrowOnceThePointHasPassed() {
        let alarm = AlarmItem(hour: 7, minute: 30)
        let now = date(2026, 3, 10, 9, 0)
        XCTAssertEqual(alarm.nextFireDate(after: now, calendar: calendar),
                       date(2026, 3, 11, 7, 30))
    }

    func testRepeatingPicksTheNearestSelectedDay() {
        // 2026-03-10 is a Tuesday.
        var alarm = AlarmItem(hour: 6, minute: 45)
        alarm.repeatDays = [.friday, .sunday]
        let now = date(2026, 3, 10, 9, 0)
        XCTAssertEqual(alarm.nextFireDate(after: now, calendar: calendar),
                       date(2026, 3, 13, 6, 45), "Friday is nearer than Sunday")
    }

    func testRepeatingSameDayStillFiresLaterThatDay() {
        var alarm = AlarmItem(hour: 22, minute: 0)
        alarm.repeatDays = [.tuesday]
        let now = date(2026, 3, 10, 9, 0)
        XCTAssertEqual(alarm.nextFireDate(after: now, calendar: calendar),
                       date(2026, 3, 10, 22, 0))
    }

    func testDisabledAlarmNeverFires() {
        var alarm = AlarmItem(hour: 7, minute: 0)
        alarm.isEnabled = false
        XCTAssertNil(alarm.nextFireDate(after: date(2026, 3, 10, 6, 0), calendar: calendar))
    }

    func testFireDatesAreMinuteAligned() {
        // The notification chain and the app both derive the character from a
        // minute slot, so a stray second would put them on different characters.
        var alarm = AlarmItem(hour: 6, minute: 45)
        alarm.repeatDays = Weekday.weekdays
        for fire in AlarmCasting.upcomingFireDates(for: alarm, limit: 5,
                                                   after: date(2026, 3, 10, 9, 0),
                                                   calendar: calendar) {
            XCTAssertEqual(calendar.component(.second, from: fire), 0)
        }
    }

    func testUpcomingFireDatesAreDistinctAndOrdered() {
        var alarm = AlarmItem(hour: 6, minute: 45)
        alarm.repeatDays = Weekday.weekdays
        let dates = AlarmCasting.upcomingFireDates(for: alarm, limit: 4,
                                                   after: date(2026, 3, 10, 9, 0),
                                                   calendar: calendar)
        XCTAssertEqual(dates.count, 4)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, 4)
    }

    func testOneShotYieldsASingleUpcomingDate() {
        let alarm = AlarmItem(hour: 7, minute: 0)
        let dates = AlarmCasting.upcomingFireDates(for: alarm, limit: 5,
                                                   after: date(2026, 3, 10, 9, 0),
                                                   calendar: calendar)
        XCTAssertEqual(dates.count, 1, "a non-repeating alarm has exactly one next time")
    }

    func testRepeatDescription() {
        var alarm = AlarmItem()
        XCTAssertEqual(alarm.repeatDescription, "Once")
        alarm.repeatDays = Weekday.weekdays
        XCTAssertEqual(alarm.repeatDescription, "Weekdays")
        alarm.repeatDays = Weekday.weekend
        XCTAssertEqual(alarm.repeatDescription, "Weekends")
        alarm.repeatDays = Set(Weekday.allCases)
        XCTAssertEqual(alarm.repeatDescription, "Every day")
        alarm.repeatDays = [.monday, .thursday]
        XCTAssertEqual(alarm.repeatDescription, "Mon Thu")
    }

    func testRoundTripsThroughJSON() throws {
        var alarm = AlarmItem(label: "Gym", hour: 5, minute: 15)
        alarm.repeatDays = [.monday, .wednesday, .friday]
        alarm.difficulty = .nightmare
        alarm.tierCeiling = .deep
        alarm.pinnedCharacterID = "vaca"

        let data = try JSONEncoder().encode(alarm)
        XCTAssertEqual(try JSONDecoder().decode(AlarmItem.self, from: data), alarm)
    }
}

final class WakeStreakTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func record(daysAgo: Int, from today: Date) -> WakeRecord {
        WakeRecord(date: calendar.date(byAdding: .day, value: -daysAgo, to: today)!,
                   alarmID: UUID(), characterID: "tralalero", difficulty: .standard,
                   secondsToDismiss: 12, misses: 0, snoozes: 0)
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 8))!
    }

    func testEmptyLog() {
        XCTAssertEqual(WakeStreak.length(of: [], asOf: today, calendar: calendar), 0)
    }

    func testConsecutiveDaysEndingToday() {
        let log = (0...3).map { record(daysAgo: $0, from: today) }
        XCTAssertEqual(WakeStreak.length(of: log, asOf: today, calendar: calendar), 4)
    }

    func testStreakSurvivesNotHavingWokenYetToday() {
        let log = (1...3).map { record(daysAgo: $0, from: today) }
        XCTAssertEqual(WakeStreak.length(of: log, asOf: today, calendar: calendar), 3)
    }

    func testGapBreaksTheStreak() {
        let log = [0, 1, 3, 4].map { record(daysAgo: $0, from: today) }
        XCTAssertEqual(WakeStreak.length(of: log, asOf: today, calendar: calendar), 2)
    }

    func testTwoDaysSilenceMeansNoStreak() {
        let log = [2, 3, 4].map { record(daysAgo: $0, from: today) }
        XCTAssertEqual(WakeStreak.length(of: log, asOf: today, calendar: calendar), 0)
    }

    func testSeveralWakesOnOneDayCountOnce() {
        let log = [record(daysAgo: 0, from: today),
                   record(daysAgo: 0, from: today),
                   record(daysAgo: 1, from: today)]
        XCTAssertEqual(WakeStreak.length(of: log, asOf: today, calendar: calendar), 2)
    }
}
