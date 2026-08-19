import Foundation
import XCTest
@testable import HabitQuest

final class DailyStreakCalculatorTests: XCTestCase {
    func testCurrentStreakCountsConsecutiveCompletedDaysAndReportsLastFullyCompletedDate() {
        let calculator = DailyStreakCalculator()
        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )

        let states = [
            Self.completedState(for: habit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.completedState(for: habit, on: Self.tuesdayMorning, calendar: Self.calendar),
            Self.completedState(for: habit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]

        let events = [
            Self.completionEvent(for: habit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.completionEvent(for: habit, on: Self.tuesdayMorning, calendar: Self.calendar),
            Self.completionEvent(for: habit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]

        let summary = calculator.summary(
            for: [habit],
            states: states,
            completionEvents: events,
            upTo: Self.wednesdayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentDailyStreak, 3)
        XCTAssertEqual(summary.longestDailyStreak, 3)
        XCTAssertEqual(summary.lastFullyCompletedDate, Self.calendar.startOfDay(for: Self.wednesdayMorning))
    }

    func testOrdinaryGapBreaksStrictStreak() {
        let calculator = DailyStreakCalculator()
        let habit = Habit(
            title: "Walk",
            schedule: .daily,
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )

        let states = [
            Self.completedState(for: habit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.pendingState(for: habit, on: Self.tuesdayMorning, calendar: Self.calendar),
            Self.completedState(for: habit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]

        let events = [
            Self.completionEvent(for: habit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.completionEvent(for: habit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]

        let summary = calculator.summary(
            for: [habit],
            states: states,
            completionEvents: events,
            upTo: Self.wednesdayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentDailyStreak, 1)
        XCTAssertEqual(summary.longestDailyStreak, 1)
        XCTAssertEqual(summary.lastFullyCompletedDate, Self.calendar.startOfDay(for: Self.wednesdayMorning))
    }

    func testPausedHabitDoesNotCountAgainstUser() {
        let calculator = DailyStreakCalculator()
        let habit = Habit(
            title: "Stretch",
            isPaused: true,
            schedule: .daily,
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )

        let states = [
            Self.pendingState(for: habit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.pendingState(for: habit, on: Self.tuesdayMorning, calendar: Self.calendar),
            Self.pendingState(for: habit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]

        let summary = calculator.summary(
            for: [habit],
            states: states,
            completionEvents: [],
            upTo: Self.wednesdayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentDailyStreak, 0)
        XCTAssertEqual(summary.longestDailyStreak, 0)
        XCTAssertNil(summary.lastFullyCompletedDate)
    }

    func testScheduleChangesDoNotRewritePersistedHistory() {
        let calculator = DailyStreakCalculator()
        let originalHabit = Habit(
            title: "Meditate",
            schedule: .daily,
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )
        let updatedHabit = Habit(
            id: originalHabit.id,
            title: "Meditate",
            schedule: .weekly(days: [.monday]),
            createdAt: Self.mondayMorning,
            updatedAt: Self.thursdayMorning
        )

        let states = [
            Self.completedState(for: originalHabit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.completedState(for: originalHabit, on: Self.tuesdayMorning, calendar: Self.calendar),
            Self.completedState(for: originalHabit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]
        let events = [
            Self.completionEvent(for: originalHabit, on: Self.mondayMorning, calendar: Self.calendar),
            Self.completionEvent(for: originalHabit, on: Self.tuesdayMorning, calendar: Self.calendar),
            Self.completionEvent(for: originalHabit, on: Self.wednesdayMorning, calendar: Self.calendar)
        ]

        let summary = calculator.summary(
            for: [updatedHabit],
            states: states,
            completionEvents: events,
            upTo: Self.wednesdayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentDailyStreak, 3)
        XCTAssertEqual(summary.longestDailyStreak, 3)
    }

    func testTimezoneAndCalendarBoundariesUseLocalDayGrouping() {
        let calculator = DailyStreakCalculator()
        let habit = Habit(
            title: "Water",
            schedule: .daily,
            createdAt: Self.timezoneCalendarDate(year: 2026, month: 8, day: 17, hour: 0, minute: 15, calendar: Self.plus14Calendar),
            updatedAt: Self.timezoneCalendarDate(year: 2026, month: 8, day: 17, hour: 0, minute: 15, calendar: Self.plus14Calendar)
        )

        let states = [
            Self.completedState(
                for: habit,
                on: Self.timezoneCalendarDate(year: 2026, month: 8, day: 16, hour: 23, minute: 50, calendar: Self.plus14Calendar),
                calendar: Self.plus14Calendar
            ),
            Self.completedState(
                for: habit,
                on: Self.timezoneCalendarDate(year: 2026, month: 8, day: 17, hour: 8, minute: 0, calendar: Self.plus14Calendar),
                calendar: Self.plus14Calendar
            )
        ]

        let events = [
            Self.completionEvent(
                for: habit,
                on: Self.timezoneCalendarDate(year: 2026, month: 8, day: 16, hour: 23, minute: 50, calendar: Self.plus14Calendar),
                calendar: Self.plus14Calendar
            ),
            Self.completionEvent(
                for: habit,
                on: Self.timezoneCalendarDate(year: 2026, month: 8, day: 17, hour: 8, minute: 0, calendar: Self.plus14Calendar),
                calendar: Self.plus14Calendar
            )
        ]

        let summary = calculator.summary(
            for: [habit],
            states: states,
            completionEvents: events,
            upTo: Self.timezoneCalendarDate(year: 2026, month: 8, day: 17, hour: 12, minute: 0, calendar: Self.plus14Calendar),
            calendar: Self.plus14Calendar
        )

        XCTAssertEqual(summary.currentDailyStreak, 2)
        XCTAssertEqual(summary.longestDailyStreak, 2)
        XCTAssertEqual(
            summary.lastFullyCompletedDate,
            Self.plus14Calendar.startOfDay(for: Self.timezoneCalendarDate(year: 2026, month: 8, day: 17, hour: 12, minute: 0, calendar: Self.plus14Calendar))
        )
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let plus14Calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600) ?? .current
        return calendar
    }()

    private static var mondayMorning: Date {
        makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: Self.calendar)
    }
    private static var tuesdayMorning: Date {
        makeDate(year: 2026, month: 8, day: 18, hour: 9, minute: 0, calendar: Self.calendar)
    }
    private static var wednesdayMorning: Date {
        makeDate(year: 2026, month: 8, day: 19, hour: 9, minute: 0, calendar: Self.calendar)
    }
    private static var wednesdayNoon: Date {
        makeDate(year: 2026, month: 8, day: 19, hour: 12, minute: 0, calendar: Self.calendar)
    }
    private static var thursdayMorning: Date {
        makeDate(year: 2026, month: 8, day: 20, hour: 9, minute: 0, calendar: Self.calendar)
    }

    private static func completedState(for habit: Habit, on date: Date, calendar: Calendar) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: date),
            status: .completed,
            completedAt: date,
            deckPriority: 10,
            currentPass: 1
        )
    }

    private static func pendingState(for habit: Habit, on date: Date, calendar: Calendar) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: date),
            status: .pending,
            deckPriority: 10,
            currentPass: 1
        )
    }

    private static func completionEvent(for habit: Habit, on date: Date, calendar: Calendar) -> CompletionEvent {
        CompletionEvent(
            habitID: habit.id,
            timestamp: date,
            logicalCompletionDate: calendar.startOfDay(for: date),
            source: .manualHabitAction
        )
    }

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
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

    private static func timezoneCalendarDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
        makeDate(year: year, month: month, day: day, hour: hour, minute: minute, calendar: calendar)
    }
}
