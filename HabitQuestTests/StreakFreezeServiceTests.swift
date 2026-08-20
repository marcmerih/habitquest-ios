import Foundation
import XCTest
@testable import HabitQuest

final class StreakFreezeServiceTests: XCTestCase {
    func testSyncCreatesStreakFreezeOpportunityAfterAStreakBreak() throws {
        let calendar = Self.utcCalendar
        let habitRepository = LocalHabitRepository.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let progressionStore = LocalHabitProgressionStore.inMemory()
        let freezeStore = LocalStreakFreezeStore.inMemory()
        let engine = DailyHabitInstanceEngine()
        let resolutionService = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: stateStore,
            dailyHabitInstanceEngine: engine,
            dailyStreakCalculator: DailyStreakCalculator(),
            streakFreezeStore: freezeStore,
            streakFreezeCostCalculator: StreakFreezeCostCalculator()
        )

        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )
        try habitRepository.createHabit(habit)

        try stateStore.saveStates([
            Self.completedState(for: habit, on: Self.mondayMorning, calendar: calendar),
            Self.completedState(for: habit, on: Self.tuesdayMorning, calendar: calendar),
            Self.pendingState(for: habit, on: Self.wednesdayMorning, calendar: calendar)
        ])

        try completionEventStore.saveEvents([
            Self.completionEvent(for: habit, on: Self.mondayMorning, calendar: calendar),
            Self.completionEvent(for: habit, on: Self.tuesdayMorning, calendar: calendar)
        ])

        _ = try resolutionService.resolveElapsedDays(
            upTo: Self.thursdayMorning,
            calendar: calendar
        )

        let service = StreakFreezeService(
            store: freezeStore,
            habitRepository: habitRepository,
            dailyHabitStateStore: stateStore,
            completionEventStore: completionEventStore,
            progressionStore: progressionStore,
            dateService: FixedDateService(now: Self.thursdayMorning, calendar: calendar)
        )

        service.syncState()

        XCTAssertEqual(service.activeOpportunity?.baselineStreak, 2)
        XCTAssertNotNil(service.activeOpportunity)
        XCTAssertGreaterThan(service.activeOpportunity?.costXP ?? 0, 0)
    }

    func testRedeemingFreezeMarksTheBrokenDayAndSpendsXP() throws {
        let calendar = Self.utcCalendar
        let habitRepository = LocalHabitRepository.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let progressionStore = LocalHabitProgressionStore.inMemory()
        let freezeStore = LocalStreakFreezeStore.inMemory()
        let engine = DailyHabitInstanceEngine()
        let resolutionService = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: stateStore,
            dailyHabitInstanceEngine: engine,
            dailyStreakCalculator: DailyStreakCalculator(),
            streakFreezeStore: freezeStore,
            streakFreezeCostCalculator: StreakFreezeCostCalculator()
        )

        let habit = Habit(
            title: "Walk",
            difficulty: 5,
            schedule: .daily,
            createdAt: Self.mondayMorning,
            updatedAt: Self.mondayMorning
        )
        try habitRepository.createHabit(habit)

        try stateStore.saveStates([
            Self.completedState(for: habit, on: Self.mondayMorning, calendar: calendar),
            Self.pendingState(for: habit, on: Self.tuesdayMorning, calendar: calendar)
        ])
        try completionEventStore.saveEvents([
            Self.completionEvent(for: habit, on: Self.mondayMorning, calendar: calendar)
        ])
        try progressionStore.saveProgression(
            HabitProgressionState(lifetimeXP: 500, lastUpdatedAt: Self.mondayMorning)
        )

        _ = try resolutionService.resolveElapsedDays(
            upTo: Self.wednesdayMorning,
            calendar: calendar
        )

        let service = StreakFreezeService(
            store: freezeStore,
            habitRepository: habitRepository,
            dailyHabitStateStore: stateStore,
            completionEventStore: completionEventStore,
            progressionStore: progressionStore,
            dateService: FixedDateService(now: Self.wednesdayMorning, calendar: calendar)
        )

        service.syncState()
        guard let opportunity = service.activeOpportunity else {
            return XCTFail("Expected a pending streak freeze opportunity.")
        }

        let result = service.purchaseFreeze()
        XCTAssertEqual(result, .saved)

        let updatedProgression = try progressionStore.loadProgression()
        XCTAssertLessThan(updatedProgression.lifetimeXP, 500)

        let resolvedStates = try stateStore.loadStates()
        let frozenDayStates = resolvedStates.filter { calendar.isDate($0.date, inSameDayAs: opportunity.brokenDay) }
        XCTAssertTrue(frozenDayStates.contains(where: { $0.streakFreezeAppliedAt != nil }))
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static var mondayMorning: Date {
        makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: utcCalendar)
    }

    private static var tuesdayMorning: Date {
        makeDate(year: 2026, month: 8, day: 18, hour: 9, minute: 0, calendar: utcCalendar)
    }

    private static var wednesdayMorning: Date {
        makeDate(year: 2026, month: 8, day: 19, hour: 9, minute: 0, calendar: utcCalendar)
    }

    private static var thursdayMorning: Date {
        makeDate(year: 2026, month: 8, day: 20, hour: 9, minute: 0, calendar: utcCalendar)
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
}

private struct FixedDateService: DateProviding {
    let now: Date
    let calendar: Calendar
}
