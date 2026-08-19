import Foundation
import XCTest
@testable import HabitQuest

final class CompletionEventProcessingTests: XCTestCase {
    func testCompletionProcessingCreatesEventAndUpdatesState() throws {
        let eventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let progressionStore = LocalHabitProgressionStore.inMemory()
        let habitRepository = LocalHabitRepository.inMemory()
        let achievementStore = LocalHabitAchievementStore.inMemory()
        let processor = HabitCompletionProcessor(
            completionEventStore: eventStore,
            dailyHabitStateStore: stateStore,
            progressionStore: progressionStore,
            achievementService: HabitAchievementService(
                achievementStore: achievementStore,
                habitRepository: habitRepository,
                completionEventStore: eventStore,
                dailyHabitStateStore: stateStore,
                progressionStore: progressionStore,
                dateService: FixedDateService(now: Self.todayNoon, calendar: Self.calendar),
                evaluator: HabitMilestoneEvaluator()
            ),
            dailyHabitInstanceEngine: DailyHabitInstanceEngine(),
            progressionCalculator: HabitProgressionCalculator()
        )

        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let state = DailyHabitState(
            habitID: habit.id,
            date: Self.todayMorning,
            status: .pending,
            deckPriority: 12,
            currentPass: 1
        )
        try stateStore.saveStates([state])

        let result = try processor.processCompletion(
            for: habit,
            state: state,
            source: CompletionSource.todayDeckSwipe,
            at: Self.todayNoon,
            calendar: Self.calendar
        )

        XCTAssertTrue(result.didCreateEvent)
        XCTAssertEqual(result.event.habitID, habit.id)
        XCTAssertEqual(result.event.source, CompletionSource.todayDeckSwipe)
        XCTAssertEqual(result.event.logicalCompletionDate, Self.calendar.startOfDay(for: Self.todayMorning))
        XCTAssertEqual(result.updatedState.status, DailyHabitStatus.completed)
        XCTAssertEqual(result.updatedState.completedAt, Self.todayNoon)
        XCTAssertEqual(try eventStore.totalCompletionCount(), 1)
        XCTAssertEqual(try eventStore.completions(for: habit.id).count, 1)
        XCTAssertEqual(try progressionStore.loadProgression().lifetimeXP, 10)

        let reloadedState = try stateStore.state(for: habit.id, on: Self.todayMorning, calendar: Self.calendar)
        XCTAssertEqual(reloadedState?.status, .completed)
        XCTAssertEqual(reloadedState?.completedAt, Self.todayNoon)
    }

    func testManualCompletionProcessingUsesManualSource() throws {
        let eventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let progressionStore = LocalHabitProgressionStore.inMemory()
        let habitRepository = LocalHabitRepository.inMemory()
        let achievementStore = LocalHabitAchievementStore.inMemory()
        let processor = HabitCompletionProcessor(
            completionEventStore: eventStore,
            dailyHabitStateStore: stateStore,
            progressionStore: progressionStore,
            achievementService: HabitAchievementService(
                achievementStore: achievementStore,
                habitRepository: habitRepository,
                completionEventStore: eventStore,
                dailyHabitStateStore: stateStore,
                progressionStore: progressionStore,
                dateService: FixedDateService(now: Self.todayNoon, calendar: Self.calendar),
                evaluator: HabitMilestoneEvaluator()
            ),
            dailyHabitInstanceEngine: DailyHabitInstanceEngine(),
            progressionCalculator: HabitProgressionCalculator()
        )

        let habit = Habit(
            title: "Journal",
            schedule: .daily,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let state = DailyHabitState(
            habitID: habit.id,
            date: Self.todayMorning,
            status: .pending,
            deckPriority: 4,
            currentPass: 1
        )
        try stateStore.saveStates([state])

        let result = try processor.processCompletion(
            for: habit,
            state: state,
            source: .manualHabitAction,
            at: Self.todayNoon,
            calendar: Self.calendar
        )

        XCTAssertTrue(result.didCreateEvent)
        XCTAssertEqual(result.event.source, .manualHabitAction)
        XCTAssertEqual(try eventStore.completions(for: habit.id).first?.source, .manualHabitAction)
    }

    func testCompletionProcessingIsIdempotentForSameHabitAndDay() throws {
        let eventStore = LocalCompletionEventStore.inMemory()
        let stateStore = LocalDailyHabitStateStore.inMemory()
        let progressionStore = LocalHabitProgressionStore.inMemory()
        let habitRepository = LocalHabitRepository.inMemory()
        let achievementStore = LocalHabitAchievementStore.inMemory()
        let processor = HabitCompletionProcessor(
            completionEventStore: eventStore,
            dailyHabitStateStore: stateStore,
            progressionStore: progressionStore,
            achievementService: HabitAchievementService(
                achievementStore: achievementStore,
                habitRepository: habitRepository,
                completionEventStore: eventStore,
                dailyHabitStateStore: stateStore,
                progressionStore: progressionStore,
                dateService: FixedDateService(now: Self.todayNoon, calendar: Self.calendar),
                evaluator: HabitMilestoneEvaluator()
            ),
            dailyHabitInstanceEngine: DailyHabitInstanceEngine(),
            progressionCalculator: HabitProgressionCalculator()
        )

        let habit = Habit(
            title: "Meditate",
            schedule: .daily,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let state = DailyHabitState(
            habitID: habit.id,
            date: Self.todayMorning,
            status: .pending,
            deckPriority: 7,
            currentPass: 1
        )
        try stateStore.saveStates([state])

        let firstResult = try processor.processCompletion(
            for: habit,
            state: state,
            source: CompletionSource.todayDeckButton,
            at: Self.todayNoon,
            calendar: Self.calendar
        )

        let secondResult = try processor.processCompletion(
            for: habit,
            state: firstResult.updatedState,
            source: CompletionSource.manualHabitAction,
            at: Self.todayNineThirty,
            calendar: Self.calendar
        )

        XCTAssertTrue(firstResult.didCreateEvent)
        XCTAssertFalse(secondResult.didCreateEvent)
        XCTAssertEqual(try eventStore.totalCompletionCount(), 1)
        XCTAssertEqual(try eventStore.completions(on: Self.todayMorning, calendar: Self.calendar).count, 1)
        XCTAssertEqual(try eventStore.completions(for: habit.id).first?.source, CompletionSource.todayDeckButton)
        XCTAssertEqual(try progressionStore.loadProgression().lifetimeXP, 10)
    }

    func testCompletionQueriesSupportHabitDateRangeAndTotals() throws {
        let store = LocalCompletionEventStore.inMemory()
        let habitA = UUID()
        let habitB = UUID()

        let events = [
            CompletionEvent(
                habitID: habitA,
                timestamp: Self.mondayMorning,
                logicalCompletionDate: Self.mondayMorning,
                source: .manualHabitAction
            ),
            CompletionEvent(
                habitID: habitA,
                timestamp: Self.tuesdayMorning,
                logicalCompletionDate: Self.tuesdayMorning,
                source: .todayDeckSwipe
            ),
            CompletionEvent(
                habitID: habitB,
                timestamp: Self.wednesdayMorning,
                logicalCompletionDate: Self.wednesdayMorning,
                source: .todayDeckButton
            )
        ]

        try store.saveEvents(events)

        XCTAssertEqual(try store.totalCompletionCount(), 3)
        XCTAssertEqual(try store.completions(for: habitA).count, 2)
        XCTAssertEqual(try store.completions(on: Self.tuesdayMorning, calendar: Self.calendar).count, 1)
        XCTAssertEqual(
            try store.completions(in: Self.mondayThroughTuesday, calendar: Self.calendar).count,
            2
        )
    }

    func testReflectionUpdatesPersistOnCompletionEvent() throws {
        let store = LocalCompletionEventStore.inMemory()
        let event = CompletionEvent(
            habitID: UUID(),
            timestamp: Self.todayNoon,
            logicalCompletionDate: Self.calendar.startOfDay(for: Self.todayMorning),
            source: .manualHabitAction
        )

        let stored = try store.upsertCompletion(event, calendar: Self.calendar)
        XCTAssertNil(stored.reflection)

        let updated = try store.updateReflection(for: stored.id, reflection: "Felt calm and steady.")
        XCTAssertEqual(updated?.reflection, "Felt calm and steady.")
        XCTAssertEqual(try store.completions(for: stored.habitID).first?.reflection, "Felt calm and steady.")

        let removed = try store.updateReflection(for: stored.id, reflection: nil)
        XCTAssertNil(removed?.reflection)
        XCTAssertNil(try store.completions(for: stored.habitID).first?.reflection)
    }

    func testCompletionEventEncodesAndDecodesReflectionContent() throws {
        let event = CompletionEvent(
            habitID: UUID(),
            timestamp: Self.todayNoon,
            logicalCompletionDate: Self.calendar.startOfDay(for: Self.todayMorning),
            source: .todayDeckButton,
            reflection: "Only ten minutes, but starting mattered."
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CompletionEvent.self, from: data)

        XCTAssertEqual(decoded.reflection, "Only ten minutes, but starting mattered.")
        XCTAssertEqual(decoded.source, .todayDeckButton)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let todayMorning = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let todayNineThirty = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 30)
    private static let todayNoon = makeDate(year: 2026, month: 8, day: 17, hour: 12, minute: 0)
    private static let mondayMorning = makeDate(year: 2026, month: 8, day: 17, hour: 8, minute: 0)
    private static let tuesdayMorning = makeDate(year: 2026, month: 8, day: 18, hour: 8, minute: 0)
    private static let wednesdayMorning = makeDate(year: 2026, month: 8, day: 19, hour: 8, minute: 0)
    private static let mondayThroughTuesday = mondayMorning...tuesdayMorning

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

private struct FixedDateService: DateProviding {
    let now: Date
    let calendar: Calendar
}
