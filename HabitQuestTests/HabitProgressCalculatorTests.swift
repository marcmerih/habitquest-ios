import Foundation
import XCTest
@testable import HabitQuest

final class HabitProgressCalculatorTests: XCTestCase {
    func testCustomWeekdayHabitProgressIgnoresNonScheduledGaps() {
        let calculator = HabitProgressCalculator()
        let habit = Habit(
            title: "Journal",
            schedule: .customDays(days: [.monday, .wednesday, .friday]),
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )

        let events = [
            completionEvent(for: habit, on: Self.mondayMorning),
            completionEvent(for: habit, on: Self.wednesdayMorning),
            completionEvent(for: habit, on: Self.fridayMorning),
            completionEvent(for: habit, on: Self.nextMondayMorning),
            completionEvent(for: habit, on: Self.nextWednesdayMorning)
        ]

        let summary = calculator.summary(
            for: habit,
            completionEvents: events,
            upTo: Self.nextWednesdayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentStreak, 5)
        XCTAssertEqual(summary.longestStreak, 5)
        XCTAssertEqual(summary.totalCompletions, 5)
        XCTAssertEqual(summary.scheduledOccurrenceCount, 5)
        XCTAssertEqual(summary.recentConsistencyPercentage, 100, accuracy: 0.001)
        XCTAssertEqual(summary.lifetimeConsistencyPercentage, 100, accuracy: 0.001)
    }

    func testBiWeeklyHabitProgressMaintainsStreakAcrossSkippedCalendarWeeks() {
        let calculator = HabitProgressCalculator()
        let habit = Habit(
            title: "Therapy",
            schedule: .biWeekly(days: [.monday]),
            createdAt: Self.firstMondayMorning,
            updatedAt: Self.firstMondayMorning
        )

        let events = [
            completionEvent(for: habit, on: Self.firstMondayMorning),
            completionEvent(for: habit, on: Self.thirdMondayMorning),
            completionEvent(for: habit, on: Self.fifthMondayMorning)
        ]

        let summary = calculator.summary(
            for: habit,
            completionEvents: events,
            upTo: Self.aug31Noon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentStreak, 3)
        XCTAssertEqual(summary.longestStreak, 3)
        XCTAssertEqual(summary.totalCompletions, 3)
        XCTAssertEqual(summary.scheduledOccurrenceCount, 3)
        XCTAssertEqual(summary.recentConsistencyPercentage, 100, accuracy: 0.001)
        XCTAssertEqual(summary.lifetimeConsistencyPercentage, 100, accuracy: 0.001)
    }

    func testWeeklyHabitProgressUsesScheduledOccurrencesForConsistency() {
        let calculator = HabitProgressCalculator()
        let habit = Habit(
            title: "Workout",
            schedule: .weekly(days: [.monday]),
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )

        let events = [
            completionEvent(for: habit, on: Self.mondayMorning),
            completionEvent(for: habit, on: Self.nextMondayMorning)
        ]

        let summary = calculator.summary(
            for: habit,
            completionEvents: events,
            upTo: Self.aug31Noon,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentStreak, 0)
        XCTAssertEqual(summary.longestStreak, 2)
        XCTAssertEqual(summary.totalCompletions, 2)
        XCTAssertEqual(summary.scheduledOccurrenceCount, 3)
        XCTAssertEqual(summary.recentConsistencyPercentage, 66.666666, accuracy: 0.001)
        XCTAssertEqual(summary.lifetimeConsistencyPercentage, 66.666666, accuracy: 0.001)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let mondayMorning = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let wednesdayMorning = makeDate(year: 2026, month: 8, day: 19, hour: 9, minute: 0)
    private static let fridayMorning = makeDate(year: 2026, month: 8, day: 21, hour: 9, minute: 0)
    private static let nextMondayMorning = makeDate(year: 2026, month: 8, day: 24, hour: 9, minute: 0)
    private static let nextWednesdayMorning = makeDate(year: 2026, month: 8, day: 26, hour: 9, minute: 0)
    private static let nextWednesdayNoon = makeDate(year: 2026, month: 8, day: 26, hour: 12, minute: 0)

    private static let firstMondayMorning = makeDate(year: 2026, month: 8, day: 3, hour: 9, minute: 0)
    private static let thirdMondayMorning = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let fifthMondayMorning = makeDate(year: 2026, month: 8, day: 31, hour: 9, minute: 0)
    private static let aug31Noon = makeDate(year: 2026, month: 8, day: 31, hour: 12, minute: 0)

    private static func completionEvent(for habit: Habit, on date: Date) -> CompletionEvent {
        CompletionEvent(
            habitID: habit.id,
            timestamp: date,
            logicalCompletionDate: calendar.startOfDay(for: date),
            source: .manualHabitAction
        )
    }

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
