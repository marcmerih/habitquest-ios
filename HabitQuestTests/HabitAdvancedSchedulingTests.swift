import Foundation
import XCTest
@testable import HabitQuest

final class HabitAdvancedSchedulingTests: XCTestCase {
    func testAdvancedSchedulePersistsThroughRepositoryRoundTrip() throws {
        let repository = LocalHabitRepository.inMemory()
        let habit = Habit(
            title: "Skincare",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .anytime,
            advancedSchedule: Self.eveningRoutineSchedule,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        try repository.createHabit(habit)

        let reloaded = try repository.fetchHabits().first
        XCTAssertEqual(reloaded?.advancedSchedule, Self.eveningRoutineSchedule)
    }

    func testAdvancedScheduleRespectsRecurringPatternAndExceptions() {
        let habit = Habit(
            title: "Journal",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .anytime,
            advancedSchedule: Self.biWeeklyMondaySchedule,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isScheduled(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.nextMonday, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.thirdMonday, calendar: Self.calendar))
        XCTAssertTrue(habit.isScheduled(on: Self.fourthMonday, calendar: Self.calendar))
    }

    func testAdvancedTimingTargetsRespectRoutineWindows() {
        let habit = Habit(
            title: "Evening reset",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .anytime,
            advancedSchedule: Self.eveningRoutineSchedule,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertFalse(habit.isCurrentlyRelevant(on: Self.morning, calendar: Self.calendar))
        XCTAssertTrue(habit.isCurrentlyRelevant(on: Self.evening, calendar: Self.calendar))
    }

    func testPremiumAccessTransitionsDoNotMutateAdvancedScheduleData() throws {
        let service = PremiumEntitlementService(accessState: .premium)
        let habit = Habit(
            title: "Practice language",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .anytime,
            advancedSchedule: Self.eveningRoutineSchedule,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(service.canAccess(.advancedScheduling))

        service.update(accessState: .free)

        XCTAssertFalse(service.canAccess(.advancedScheduling))
        XCTAssertEqual(habit.advancedSchedule, Self.eveningRoutineSchedule)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let referenceDate = makeDate(year: 2026, month: 8, day: 3, hour: 9, minute: 0)
    private static let nextMonday = makeDate(year: 2026, month: 8, day: 10, hour: 9, minute: 0)
    private static let thirdMonday = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let fourthMonday = makeDate(year: 2026, month: 8, day: 24, hour: 9, minute: 0)
    private static let morning = makeDate(year: 2026, month: 8, day: 3, hour: 8, minute: 0)
    private static let evening = makeDate(year: 2026, month: 8, day: 3, hour: 19, minute: 0)

    private static let biWeeklyMondaySchedule = HabitAdvancedSchedule(
        rules: [
            .weekdayPattern(
                HabitAdvancedWeekdayPattern(
                    weekdays: [.monday],
                    intervalWeeks: 2,
                    anchorDate: referenceDate
                )
            ),
            .timeWindow(
                HabitTimeWindow(
                    start: HabitClockTime(hour: 8, minute: 0),
                    end: HabitClockTime(hour: 20, minute: 0)
                )
            )
        ],
        exceptions: [
            HabitScheduleException(date: thirdMonday)
        ],
        createdAt: referenceDate
    )

    private static let eveningRoutineSchedule = HabitAdvancedSchedule(
        rules: [
            .routineTarget(.evening),
            .timeWindow(
                HabitTimeWindow(
                    start: HabitClockTime(hour: 18, minute: 0),
                    end: HabitClockTime(hour: 21, minute: 0)
                )
            )
        ],
        createdAt: referenceDate
    )

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
