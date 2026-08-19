import Foundation
import XCTest
@testable import HabitQuest

final class HabitAnalyticsCalculatorTests: XCTestCase {
    func testReportCalculatesCoreAnalyticsAcrossRange() {
        let calculator = HabitAnalyticsCalculator()
        let morningHabit = Habit(
            title: "Walk",
            schedule: .daily,
            dailyRhythm: .morning,
            createdAt: Self.rangeStart,
            updatedAt: Self.rangeStart
        )
        let anytimeHabit = Habit(
            title: "Hydrate",
            schedule: .daily,
            dailyRhythm: .anytime,
            createdAt: Self.rangeStart,
            updatedAt: Self.rangeStart
        )
        let eveningHabit = Habit(
            title: "Skincare",
            schedule: .weekly(days: [.monday, .wednesday, .friday]),
            dailyRhythm: .evening,
            createdAt: Self.rangeStart,
            updatedAt: Self.rangeStart
        )
        let monthlyHabit = Habit(
            title: "Review",
            schedule: .monthly(dayOfMonth: 15),
            dailyRhythm: .day,
            createdAt: Self.calendar.startOfDay(for: Self.date(year: 2026, month: 7, day: 15, hour: 9, minute: 0)),
            updatedAt: Self.calendar.startOfDay(for: Self.date(year: 2026, month: 7, day: 15, hour: 9, minute: 0))
        )

        let habits = [morningHabit, anytimeHabit, eveningHabit, monthlyHabit]

        let completionEvents: [CompletionEvent] = [
            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 11, hour: 8, minute: 0)),
            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 11, hour: 9, minute: 0)),

            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 12, hour: 9, minute: 0)),

            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 13, hour: 8, minute: 0)),

            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 14, hour: 8, minute: 0)),
            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 14, hour: 9, minute: 0)),

            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 15, hour: 8, minute: 0)),
            Self.event(for: monthlyHabit, on: Self.date(year: 2026, month: 8, day: 15, hour: 10, minute: 0)),

            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 16, hour: 8, minute: 0)),

            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 17, hour: 9, minute: 0)),
            Self.event(for: eveningHabit, on: Self.date(year: 2026, month: 8, day: 17, hour: 20, minute: 0))
        ]

        let morningStates = [
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 11, hour: 12, minute: 0), deferCount: 0),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 12, hour: 12, minute: 0), deferCount: 0),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 13, hour: 12, minute: 0), deferCount: 1),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 14, hour: 12, minute: 0), deferCount: 2),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 15, hour: 12, minute: 0), deferCount: 1),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 16, hour: 12, minute: 0), deferCount: 0),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 17, hour: 12, minute: 0), deferCount: 0)
        ]

        let report = calculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: morningStates,
            in: Self.rangeStart...Self.rangeEnd,
            calendar: Self.calendar
        )

        XCTAssertEqual(report.rangeStart, Self.calendar.startOfDay(for: Self.rangeStart))
        XCTAssertEqual(report.rangeEnd, Self.calendar.startOfDay(for: Self.rangeEnd))
        XCTAssertEqual(report.totalCompletions, 10)
        XCTAssertEqual(report.completionRate ?? -1, 55.55555555555556, accuracy: 0.001)

        XCTAssertEqual(report.dailyCompletionHistory.count, 7)
        XCTAssertEqual(report.dailyCompletionHistory.first?.date, Self.calendar.startOfDay(for: Self.rangeStart))
        XCTAssertEqual(report.dailyCompletionHistory.first?.dueCount, 3)
        XCTAssertEqual(report.dailyCompletionHistory.first?.completedCount, 2)
        XCTAssertEqual(report.dailyCompletionHistory.first?.completionRate ?? -1, 66.66666666666666, accuracy: 0.001)

        let august14 = report.dailyCompletionHistory[3]
        XCTAssertEqual(august14.date, Self.calendar.startOfDay(for: Self.date(year: 2026, month: 8, day: 14, hour: 12, minute: 0)))
        XCTAssertEqual(august14.dueCount, 2)
        XCTAssertEqual(august14.completedCount, 2)
        XCTAssertEqual(august14.completionRate ?? -1, 100, accuracy: 0.001)

        let august15 = report.dailyCompletionHistory[4]
        XCTAssertEqual(august15.dueCount, 4)
        XCTAssertEqual(august15.completedCount, 2)
        XCTAssertEqual(august15.completionRate ?? -1, 50, accuracy: 0.001)

        XCTAssertEqual(report.weeklyConsistency.count, 1)
        XCTAssertEqual(report.weeklyConsistency.first?.dueCount, 18)
        XCTAssertEqual(report.weeklyConsistency.first?.completedCount, 10)
        XCTAssertEqual(report.weeklyConsistency.first?.completionRate ?? -1, 55.55555555555556, accuracy: 0.001)

        XCTAssertEqual(report.monthlyConsistency.count, 1)
        XCTAssertEqual(report.monthlyConsistency.first?.dueCount, 18)
        XCTAssertEqual(report.monthlyConsistency.first?.completedCount, 10)
        XCTAssertEqual(report.monthlyConsistency.first?.completionRate ?? -1, 55.55555555555556, accuracy: 0.001)

        XCTAssertEqual(report.momentumHistory.count, 7)
        XCTAssertGreaterThan(report.momentumSummary.currentMomentum, report.momentumSummary.previousMomentum)
        XCTAssertEqual(report.momentumSummary.trend.direction, .rising)

        XCTAssertEqual(report.individualHabitStreaks.count, 4)
        XCTAssertEqual(report.individualHabitStreaks[morningHabit.id]?.currentStreak, 0)
        XCTAssertEqual(report.individualHabitStreaks[morningHabit.id]?.longestStreak, 4)
        XCTAssertEqual(report.individualHabitStreaks[anytimeHabit.id]?.longestStreak, 1)
        XCTAssertEqual(report.personalBests.longestHabitStreak, 4)
        XCTAssertEqual(report.personalBests.longestDailyStreak, 1)

        XCTAssertEqual(report.completionRateByHabit[morningHabit.id] ?? -1, 71.42857142857143, accuracy: 0.001)
        XCTAssertEqual(report.completionRateByHabit[monthlyHabit.id] ?? -1, 100, accuracy: 0.001)

        XCTAssertEqual(report.strongestDaysOfWeek.first?.weekday, .thursday)
        XCTAssertEqual(report.strongestDaysOfWeek.first?.completionRate ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(report.strongestDaysOfWeek.first?.dueCount, 2)

        let morningRhythm = report.completionBehaviorByDailyRhythm.first { $0.rhythm == .morning }
        let dayRhythm = report.completionBehaviorByDailyRhythm.first { $0.rhythm == .day }
        let eveningRhythm = report.completionBehaviorByDailyRhythm.first { $0.rhythm == .evening }
        let anytimeRhythm = report.completionBehaviorByDailyRhythm.first { $0.rhythm == .anytime }

        XCTAssertEqual(morningRhythm?.dueCount, 7)
        XCTAssertEqual(morningRhythm?.completedCount, 5)
        XCTAssertEqual(morningRhythm?.completionRate ?? -1, 71.42857142857143, accuracy: 0.001)
        XCTAssertEqual(dayRhythm?.dueCount, 1)
        XCTAssertEqual(dayRhythm?.completedCount, 1)
        XCTAssertEqual(dayRhythm?.completionRate ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(eveningRhythm?.dueCount, 3)
        XCTAssertEqual(eveningRhythm?.completedCount, 1)
        XCTAssertEqual(eveningRhythm?.completionRate ?? -1, 33.33333333333333, accuracy: 0.001)
        XCTAssertEqual(anytimeRhythm?.dueCount, 7)
        XCTAssertEqual(anytimeRhythm?.completedCount, 3)
        XCTAssertEqual(anytimeRhythm?.completionRate ?? -1, 42.857142857142854, accuracy: 0.001)

        XCTAssertEqual(report.deferralFrequencyByHabit[morningHabit.id] ?? -1, 4.0 / 7.0 * 100.0, accuracy: 0.001)
        XCTAssertEqual(report.personalBests.bestDay?.date, Self.calendar.startOfDay(for: Self.date(year: 2026, month: 8, day: 14, hour: 12, minute: 0)))
        XCTAssertEqual(report.personalBests.bestDay?.completionRate ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(report.personalBests.bestWeek?.completionRate ?? -1, 55.55555555555556, accuracy: 0.001)
        XCTAssertEqual(report.personalBests.bestMonth?.completionRate ?? -1, 55.55555555555556, accuracy: 0.001)
        XCTAssertGreaterThan(report.personalBests.highestMomentum, 0)
        XCTAssertLessThanOrEqual(report.personalBests.highestMomentum, 100)
        XCTAssertEqual(report.personalBests.mostCompletionsInDay, 2)
    }

    func testIndividualHabitStreaksRespectWeeklyRecurrencePattern() {
        let calculator = HabitAnalyticsCalculator()
        let habit = Habit(
            title: "Strength",
            schedule: .weekly(days: [.monday, .wednesday, .friday]),
            dailyRhythm: .day,
            createdAt: Self.calendar.startOfDay(for: Self.date(year: 2026, month: 8, day: 3, hour: 9, minute: 0)),
            updatedAt: Self.calendar.startOfDay(for: Self.date(year: 2026, month: 8, day: 3, hour: 9, minute: 0))
        )

        let events = [
            Self.event(for: habit, on: Self.date(year: 2026, month: 8, day: 3, hour: 18, minute: 0)),
            Self.event(for: habit, on: Self.date(year: 2026, month: 8, day: 5, hour: 18, minute: 0)),
            Self.event(for: habit, on: Self.date(year: 2026, month: 8, day: 7, hour: 18, minute: 0)),
            Self.event(for: habit, on: Self.date(year: 2026, month: 8, day: 10, hour: 18, minute: 0)),
            Self.event(for: habit, on: Self.date(year: 2026, month: 8, day: 12, hour: 18, minute: 0)),
            Self.event(for: habit, on: Self.date(year: 2026, month: 8, day: 14, hour: 18, minute: 0))
        ]

        let report = calculator.report(
            for: [habit],
            completionEvents: events,
            in: Self.calendar.startOfDay(for: Self.date(year: 2026, month: 8, day: 3, hour: 12, minute: 0))...Self.calendar.startOfDay(for: Self.date(year: 2026, month: 8, day: 14, hour: 12, minute: 0)),
            calendar: Self.calendar
        )

        let summary = report.individualHabitStreaks[habit.id]
        XCTAssertEqual(summary?.currentStreak, 6)
        XCTAssertEqual(summary?.longestStreak, 6)
        XCTAssertEqual(summary?.totalCompletions, 6)
        XCTAssertEqual(report.completionRateByHabit[habit.id] ?? -1, 100, accuracy: 0.001)
    }

    func testPremiumAnalyticsReportBuildsLongRangeSummariesAndInsights() {
        let calculator = HabitPremiumAnalyticsCalculator()
        let morningHabit = Habit(
            title: "Walk",
            schedule: .daily,
            dailyRhythm: .morning,
            createdAt: Self.rangeStart,
            updatedAt: Self.rangeStart
        )
        let anytimeHabit = Habit(
            title: "Hydrate",
            schedule: .daily,
            dailyRhythm: .anytime,
            createdAt: Self.rangeStart,
            updatedAt: Self.rangeStart
        )
        let eveningHabit = Habit(
            title: "Skincare",
            schedule: .weekly(days: [.monday, .wednesday, .friday]),
            dailyRhythm: .evening,
            createdAt: Self.rangeStart,
            updatedAt: Self.rangeStart
        )

        let habits = [morningHabit, anytimeHabit, eveningHabit]

        let completionEvents: [CompletionEvent] = [
            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 11, hour: 8, minute: 0)),
            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 11, hour: 9, minute: 0)),
            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 12, hour: 9, minute: 0)),
            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 13, hour: 8, minute: 0)),
            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 14, hour: 8, minute: 0)),
            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 14, hour: 9, minute: 0)),
            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 15, hour: 8, minute: 0)),
            Self.event(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 16, hour: 8, minute: 0)),
            Self.event(for: anytimeHabit, on: Self.date(year: 2026, month: 8, day: 17, hour: 9, minute: 0)),
            Self.event(for: eveningHabit, on: Self.date(year: 2026, month: 8, day: 17, hour: 20, minute: 0))
        ]

        let states = [
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 11, hour: 12, minute: 0), deferCount: 0),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 12, hour: 12, minute: 0), deferCount: 0),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 13, hour: 12, minute: 0), deferCount: 1),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 14, hour: 12, minute: 0), deferCount: 2),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 15, hour: 12, minute: 0), deferCount: 1),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 16, hour: 12, minute: 0), deferCount: 0),
            Self.state(for: morningHabit, on: Self.date(year: 2026, month: 8, day: 17, hour: 12, minute: 0), deferCount: 0)
        ]

        let report = calculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: states,
            in: Self.rangeStart...Self.rangeEnd,
            calendar: Self.calendar
        )

        XCTAssertEqual(report.windowSummaries.map(\.preset), [.thirtyDays, .ninetyDays, .year, .allTime])

        let thirtyDaySummary = report.windowSummaries.first(where: { $0.preset == .thirtyDays })
        let ninetyDaySummary = report.windowSummaries.first(where: { $0.preset == .ninetyDays })
        let allTimeSummary = report.windowSummaries.first(where: { $0.preset == .allTime })

        XCTAssertEqual(thirtyDaySummary?.label, "30 days")
        XCTAssertEqual(ninetyDaySummary?.label, "90 days")
        XCTAssertEqual(allTimeSummary?.label, "All time")
        XCTAssertNotNil(report.comparison)
        XCTAssertEqual(report.completionRateTrend.count, 4)
        XCTAssertEqual(report.momentumTrend.count, 4)
        XCTAssertEqual(report.strongestDaysOfWeek.first?.weekday, .thursday)
        XCTAssertNotNil(report.weakestDaysOfWeek.first)
        XCTAssertEqual(report.routinePerformance.count, 4)

        let morningRoutine = report.routinePerformance.first { $0.rhythm == .morning }
        let eveningRoutine = report.routinePerformance.first { $0.rhythm == .evening }
        XCTAssertGreaterThan(morningRoutine?.completionRate ?? 0, eveningRoutine?.completionRate ?? 0)

        XCTAssertEqual(Set(report.habitTrends.map(\.habitID)), Set([morningHabit.id, anytimeHabit.id, eveningHabit.id]))
        XCTAssertTrue(report.deferralPatterns.contains(where: { $0.habitID == morningHabit.id }))
        XCTAssertFalse(report.insights.isEmpty)
        XCTAssertTrue(Set(report.insights.map(\.id)).contains("bestRoutine"))
        XCTAssertTrue(Set(report.insights.map(\.id)).contains("allTimeConsistency"))
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static var rangeStart: Date {
        date(year: 2026, month: 8, day: 11, hour: 0, minute: 0)
    }

    private static var rangeEnd: Date {
        date(year: 2026, month: 8, day: 17, hour: 23, minute: 59)
    }

    private static func event(for habit: Habit, on date: Date) -> CompletionEvent {
        CompletionEvent(
            habitID: habit.id,
            timestamp: date,
            logicalCompletionDate: calendar.startOfDay(for: date),
            source: .manualHabitAction
        )
    }

    private static func state(for habit: Habit, on date: Date, deferCount: Int) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: date),
            status: .deferred,
            deferCount: deferCount,
            lastDeferredAt: date,
            deckPriority: 10,
            currentPass: 1,
            nextEligibleAt: date
        )
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
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
