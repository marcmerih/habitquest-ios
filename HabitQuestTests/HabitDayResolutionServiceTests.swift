import Foundation
import XCTest
@testable import HabitQuest

final class HabitDayResolutionServiceTests: XCTestCase {
    func testMidnightTransitionExpiresDeferredStateAndLeavesTodayFresh() throws {
        let calendar = Self.utcCalendar
        let habitRepository = LocalHabitRepository.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let engine = DailyHabitInstanceEngine()
        let service = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: stateStore,
            dailyHabitInstanceEngine: engine
        )

        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.day(year: 2026, month: 8, day: 16, hour: 9, minute: 0, calendar: calendar),
            updatedAt: Self.day(year: 2026, month: 8, day: 16, hour: 9, minute: 0, calendar: calendar)
        )
        try habitRepository.createHabit(habit)

        let deferredYesterday = DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: Self.day(year: 2026, month: 8, day: 16, hour: 9, minute: 0, calendar: calendar)),
            status: .deferred,
            deferCount: 2,
            lastDeferredAt: Self.day(year: 2026, month: 8, day: 16, hour: 21, minute: 0, calendar: calendar),
            deckPriority: 12,
            currentPass: 3,
            nextEligibleAt: Self.day(year: 2026, month: 8, day: 16, hour: 21, minute: 30, calendar: calendar)
        )
        try stateStore.saveStates([deferredYesterday])

        let result = try service.resolveElapsedDays(
            upTo: Self.day(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(result.resolvedDayCount, 1)

        let resolvedStates = try stateStore.loadStates()
        let yesterdayState = resolvedStates.first { calendar.isDate($0.date, inSameDayAs: Self.day(year: 2026, month: 8, day: 16, hour: 9, minute: 0, calendar: calendar)) }

        XCTAssertEqual(yesterdayState?.status, .expired)
        XCTAssertEqual(yesterdayState?.deferCount, 2)
        XCTAssertNotNil(yesterdayState?.lastDeferredAt)

        let todaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: resolvedStates,
            on: Self.day(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: calendar),
            now: Self.day(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(todaySnapshot.states.first?.status, .pending)
    }

    func testClosedAcrossSeveralDaysResolvesEachElapsedDay() throws {
        let calendar = Self.utcCalendar
        let habitRepository = LocalHabitRepository.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let engine = DailyHabitInstanceEngine()
        let service = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: stateStore,
            dailyHabitInstanceEngine: engine
        )

        let habit = Habit(
            title: "Journal",
            schedule: .daily,
            createdAt: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 0, calendar: calendar),
            updatedAt: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 0, calendar: calendar)
        )
        try habitRepository.createHabit(habit)

        let completedStart = DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 0, calendar: calendar)),
            status: .completed,
            completedAt: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 10, calendar: calendar),
            deckPriority: 10,
            currentPass: 1
        )
        try stateStore.saveStates([completedStart])
        try completionEventStore.saveEvents([
            CompletionEvent(
                habitID: habit.id,
                timestamp: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 10, calendar: calendar),
                logicalCompletionDate: calendar.startOfDay(for: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 10, calendar: calendar)),
                source: .manualHabitAction
            )
        ])

        let result = try service.resolveElapsedDays(
            upTo: Self.day(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(result.resolvedDayCount, 3)

        let resolvedStates = try stateStore.loadStates()
        let day14 = resolvedStates.first { calendar.isDate($0.date, inSameDayAs: Self.day(year: 2026, month: 8, day: 14, hour: 9, minute: 0, calendar: calendar)) }
        let day15 = resolvedStates.first { calendar.isDate($0.date, inSameDayAs: Self.day(year: 2026, month: 8, day: 15, hour: 9, minute: 0, calendar: calendar)) }
        let day16 = resolvedStates.first { calendar.isDate($0.date, inSameDayAs: Self.day(year: 2026, month: 8, day: 16, hour: 9, minute: 0, calendar: calendar)) }

        XCTAssertEqual(day14?.status, .completed)
        XCTAssertEqual(day15?.status, .expired)
        XCTAssertEqual(day16?.status, .expired)
    }

    func testDaylightSavingChangesResolveAcrossCalendarDays() throws {
        let calendar = Self.newYorkCalendar
        let habitRepository = LocalHabitRepository.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let engine = DailyHabitInstanceEngine()
        let service = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: stateStore,
            dailyHabitInstanceEngine: engine
        )

        let habit = Habit(
            title: "Walk",
            schedule: .daily,
            createdAt: Self.day(year: 2026, month: 3, day: 6, hour: 9, minute: 0, calendar: calendar),
            updatedAt: Self.day(year: 2026, month: 3, day: 6, hour: 9, minute: 0, calendar: calendar)
        )
        try habitRepository.createHabit(habit)

        try stateStore.saveStates([
            DailyHabitState(
                habitID: habit.id,
                date: calendar.startOfDay(for: Self.day(year: 2026, month: 3, day: 6, hour: 9, minute: 0, calendar: calendar)),
                status: .pending,
                deckPriority: 10,
                currentPass: 1
            )
        ])

        let result = try service.resolveElapsedDays(
            upTo: Self.day(year: 2026, month: 3, day: 10, hour: 9, minute: 0, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(result.resolvedDayCount, 4)

        let resolvedStates = try stateStore.loadStates()
        XCTAssertEqual(
            resolvedStates.filter { $0.habitID == habit.id && $0.status == .expired }.count,
            4
        )
        XCTAssertEqual(
            resolvedStates.first { calendar.isDate($0.date, inSameDayAs: Self.day(year: 2026, month: 3, day: 6, hour: 9, minute: 0, calendar: calendar)) }?.status,
            .expired
        )
    }

    func testTimezoneChangesUseTheProvidedCalendarForResolution() throws {
        let utcCalendar = Self.utcCalendar
        let plus14Calendar = Self.plus14Calendar
        let habitRepository = LocalHabitRepository.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let engine = DailyHabitInstanceEngine()
        let service = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: stateStore,
            dailyHabitInstanceEngine: engine
        )

        let habit = Habit(
            title: "Hydrate",
            schedule: .daily,
            createdAt: Self.day(year: 2026, month: 8, day: 16, hour: 8, minute: 0, calendar: utcCalendar),
            updatedAt: Self.day(year: 2026, month: 8, day: 16, hour: 8, minute: 0, calendar: utcCalendar)
        )
        try habitRepository.createHabit(habit)

        let storedStateDate = Self.day(year: 2026, month: 8, day: 16, hour: 23, minute: 30, calendar: utcCalendar)
        try stateStore.saveStates([
            DailyHabitState(
                habitID: habit.id,
                date: storedStateDate,
                status: .pending,
                deckPriority: 9,
                currentPass: 1
            )
        ])

        let result = try service.resolveElapsedDays(
            upTo: Self.day(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: plus14Calendar),
            calendar: plus14Calendar
        )

        XCTAssertEqual(result.resolvedDayCount, 0)

        let reloadedState = try stateStore.loadStates().first
        XCTAssertEqual(reloadedState?.status, .pending)
        XCTAssertTrue(plus14Calendar.isDate(reloadedState?.date ?? .distantPast, inSameDayAs: Self.day(year: 2026, month: 8, day: 17, hour: 9, minute: 0, calendar: plus14Calendar)))
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let plus14Calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600) ?? .current
        return calendar
    }()

    private static let newYorkCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone(secondsFromGMT: -5 * 3600) ?? .current
        return calendar
    }()

    private static func day(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
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
