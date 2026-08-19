import Foundation
import XCTest
@testable import HabitQuest

final class HabitMomentumCalculatorTests: XCTestCase {
    func testMomentumStaysAtFullScoreDuringSustainedConsistency() {
        let calculator = HabitMomentumCalculator()
        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.sixtyDaysAgoMorning,
            updatedAt: Self.sixtyDaysAgoMorning
        )

        let events = Self.completionEvents(
            for: habit,
            completedDayOffsets: Set(0..<60),
            totalDays: 60
        )

        let summary = calculator.summary(
            for: [habit],
            completionEvents: events,
            upTo: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(summary.currentMomentum, 100, accuracy: 0.001)
        XCTAssertEqual(summary.previousMomentum, 100, accuracy: 0.001)
        XCTAssertEqual(summary.trend.direction, .steady)
        XCTAssertEqual(summary.recentHistory.count, 30)
        XCTAssertTrue(summary.recentHistory.allSatisfy { $0.value == 100 })
    }

    func testSingleImperfectDayBarelyMovesMomentum() {
        let calculator = HabitMomentumCalculator()
        let habit = Habit(
            title: "Walk",
            schedule: .daily,
            createdAt: Self.sixtyDaysAgoMorning,
            updatedAt: Self.sixtyDaysAgoMorning
        )

        var completedDays = Set(0..<60)
        completedDays.remove(59)

        let events = Self.completionEvents(
            for: habit,
            completedDayOffsets: completedDays,
            totalDays: 60
        )

        let summary = calculator.summary(
            for: [habit],
            completionEvents: events,
            upTo: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertLessThan(summary.currentMomentum, 100)
        XCTAssertGreaterThan(summary.currentMomentum, 95)
        XCTAssertEqual(summary.previousMomentum, 100, accuracy: 0.001)
        XCTAssertEqual(summary.trend.direction, .falling)
        XCTAssertLessThan(summary.trend.delta, 0)
    }

    func testSustainedInactivityDropsMomentumGradually() {
        let calculator = HabitMomentumCalculator()
        let habit = Habit(
            title: "Journal",
            schedule: .daily,
            createdAt: Self.sixtyDaysAgoMorning,
            updatedAt: Self.sixtyDaysAgoMorning
        )

        let completedDays = Set(0..<45)
        let events = Self.completionEvents(
            for: habit,
            completedDayOffsets: completedDays,
            totalDays: 60
        )

        let summary = calculator.summary(
            for: [habit],
            completionEvents: events,
            upTo: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertLessThan(summary.currentMomentum, 60)
        XCTAssertGreaterThan(summary.currentMomentum, 0)
        XCTAssertEqual(summary.previousMomentum, 100, accuracy: 0.001)
        XCTAssertEqual(summary.trend.direction, .falling)
        XCTAssertEqual(summary.recentHistory.prefix(15).compactMap(\.value).allSatisfy { $0 == 100 }, true)
        XCTAssertEqual(summary.recentHistory.suffix(15).compactMap(\.value).allSatisfy { $0 == 0 }, true)
    }

    func testNeutralDaysWithoutHabitsDoNotAffectMomentum() {
        let calculator = HabitMomentumCalculator()
        let habit = Habit(
            title: "Meditate",
            schedule: .weekly(days: [.monday]),
            createdAt: Self.mondayTwoWeeksAgoMorning,
            updatedAt: Self.mondayTwoWeeksAgoMorning
        )

        let events = [
            CompletionEvent(
                habitID: habit.id,
                timestamp: Self.previousMondayMorning,
                logicalCompletionDate: Self.calendar.startOfDay(for: Self.previousMondayMorning),
                source: .manualHabitAction
            )
        ]

        let summary = calculator.summary(
            for: [habit],
            completionEvents: events,
            upTo: Self.sundayMorning,
            calendar: Self.calendar,
            windowDays: 7
        )

        XCTAssertEqual(summary.currentMomentum, 100, accuracy: 0.001)
        XCTAssertEqual(summary.previousMomentum, 0, accuracy: 0.001)
        XCTAssertEqual(summary.recentHistory.count, 7)
        XCTAssertEqual(summary.recentHistory.filter { $0.value == nil }.count, 6)
        XCTAssertEqual(summary.recentHistory.compactMap(\.value).count, 1)
    }

    func testTrendReflectsCurrentAgainstPreviousWindow() {
        let calculator = HabitMomentumCalculator()
        let habit = Habit(
            title: "Practice",
            schedule: .daily,
            createdAt: Self.sixtyDaysAgoMorning,
            updatedAt: Self.sixtyDaysAgoMorning
        )

        let completedDays = Set(0..<30)
        let events = Self.completionEvents(
            for: habit,
            completedDayOffsets: completedDays,
            totalDays: 60
        )

        let summary = calculator.summary(
            for: [habit],
            completionEvents: events,
            upTo: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertLessThan(summary.currentMomentum, summary.previousMomentum)
        XCTAssertEqual(summary.trend.direction, .falling)
        XCTAssertLessThan(summary.trend.delta, 0)
        XCTAssertEqual(summary.recentHistory.count, 30)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static var todayMorning: Date {
        makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 0)
    }

    private static var sixtyDaysAgoMorning: Date {
        makeDate(year: 2026, month: 6, day: 18, hour: 9, minute: 0)
    }

    private static var mondayTwoWeeksAgoMorning: Date {
        makeDate(year: 2026, month: 8, day: 3, hour: 9, minute: 0)
    }

    private static var sundayMorning: Date {
        makeDate(year: 2026, month: 8, day: 9, hour: 9, minute: 0)
    }

    private static var previousMondayMorning: Date {
        makeDate(year: 2026, month: 8, day: 3, hour: 9, minute: 0)
    }

    private static func completionEvents(
        for habit: Habit,
        completedDayOffsets: Set<Int>,
        totalDays: Int
    ) -> [CompletionEvent] {
        let startDay = calendar.startOfDay(for: sixtyDaysAgoMorning)

        return (0..<totalDays).compactMap { offset in
            guard completedDayOffsets.contains(offset),
                  let day = calendar.date(byAdding: .day, value: offset, to: startDay) else {
                return nil
            }

            return CompletionEvent(
                habitID: habit.id,
                timestamp: day,
                logicalCompletionDate: day,
                source: .manualHabitAction
            )
        }
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
