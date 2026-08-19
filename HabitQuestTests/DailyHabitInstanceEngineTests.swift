import Foundation
import XCTest
@testable import HabitQuest

final class DailyHabitInstanceEngineTests: XCTestCase {
    func testYesterdayIncompleteStateExpiresAndTodayGetsFreshInstance() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.yesterdayMorning,
            updatedAt: Self.yesterdayMorning
        )

        let yesterdayState = DailyHabitState(
            habitID: habit.id,
            date: Self.yesterdayMorning,
            status: .deferred,
            deferCount: 2,
            lastDeferredAt: Self.yesterdayNoon,
            deckPriority: 12,
            currentPass: 3,
            nextEligibleAt: Self.yesterdayNoon
        )

        let reconciled = engine.reconcileHistoricalStates(
            [yesterdayState],
            currentDate: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(reconciled.first?.status, .expired)
        XCTAssertNil(reconciled.first?.nextEligibleAt)

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: reconciled,
            on: Self.todayMorning,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(snapshot.states.count, 1)
        XCTAssertEqual(snapshot.states.first?.habitID, habit.id)
        XCTAssertTrue(Self.calendar.isDate(snapshot.states.first?.date ?? .distantPast, inSameDayAs: Self.todayMorning))
        XCTAssertEqual(snapshot.states.first?.status, .pending)
        XCTAssertEqual(snapshot.states.first?.deferCount, 0)
        XCTAssertEqual(snapshot.states.first?.currentPass, 1)
        XCTAssertGreaterThan(snapshot.states.first?.deckPriority ?? 0, 0)
    }

    func testDeferringDoesNotChangeHabitScheduleAndAdvancesDailyState() throws {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Gym",
            schedule: .weekly(days: [.monday]),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        guard let initialState = snapshot.states.first else {
            return XCTFail("Expected a generated daily state.")
        }

        let deferredState = engine.deferState(
            initialState,
            habit: habit,
            remainingActionableHabits: 3,
            at: Self.todayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(habit.schedule, .weekly(days: [.monday]))
        XCTAssertEqual(deferredState.status, .deferred)
        XCTAssertEqual(deferredState.deferCount, 1)
        XCTAssertEqual(deferredState.currentPass, 2)
        XCTAssertEqual(deferredState.lastDeferredAt, Self.todayNoon)
        XCTAssertNotNil(deferredState.nextEligibleAt)
        XCTAssertGreaterThan(deferredState.nextEligibleAt ?? .distantPast, Self.todayNoon)

        let store = LocalDailyHabitStateStore.inMemory()
        try store.saveStates([deferredState])
        let reloaded = try store.loadStates()

        XCTAssertEqual(reloaded, [deferredState])
    }

    func testDeferredHabitStaysOutOfTheCurrentPassUntilThePassIsComplete() {
        let engine = DailyHabitInstanceEngine()
        let habits = Self.makeDeckHabits()

        let initialSnapshot = engine.generateSnapshot(
            for: habits,
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        guard let initialState = initialSnapshot.states.first,
              let initialHabit = habits.first(where: { $0.id == initialState.habitID }) else {
            return XCTFail("Expected an initial deck state.")
        }

        let deferredState = engine.deferState(
            initialState,
            habit: initialHabit,
            remainingActionableHabits: 2,
            at: Self.todayMorning,
            calendar: Self.calendar
        )
        let deferredStates = initialSnapshot.states.map { $0.habitID == deferredState.habitID ? deferredState : $0 }

        let midPassSnapshot = engine.generateSnapshot(
            for: habits,
            persistedStates: deferredStates,
            on: Self.todayMorning,
            now: Self.todayNineOhTwo,
            calendar: Self.calendar
        )

        XCTAssertEqual(midPassSnapshot.actionableStates.count, 2)
        XCTAssertEqual(midPassSnapshot.waitingDeferredStates.count, 1)
        XCTAssertTrue(midPassSnapshot.waitingDeferredStates.contains(where: { $0.habitID == deferredState.habitID }))
        XCTAssertFalse(midPassSnapshot.actionableStates.contains(where: { $0.habitID == deferredState.habitID }))

        let completedCurrentPassStates = midPassSnapshot.states.map { state -> DailyHabitState in
            guard state.habitID != deferredState.habitID, state.status == .pending else {
                return state
            }

            return engine.complete(state, at: Self.todayNineOhThree)
        }

        let waitingSnapshot = engine.generateSnapshot(
            for: habits,
            persistedStates: completedCurrentPassStates,
            on: Self.todayMorning,
            now: Self.todayNineOhThree,
            calendar: Self.calendar
        )

        XCTAssertEqual(waitingSnapshot.actionableStates.count, 0)
        XCTAssertEqual(waitingSnapshot.waitingDeferredStates.count, 1)
        XCTAssertEqual(waitingSnapshot.waitingDeferredStates.first?.status, .deferred)
        XCTAssertEqual(waitingSnapshot.waitingDeferredStates.first?.habitID, deferredState.habitID)

        let nextPassSnapshot = engine.generateSnapshot(
            for: habits,
            persistedStates: completedCurrentPassStates,
            on: Self.todayMorning,
            now: Self.todayNineOhSix,
            calendar: Self.calendar
        )

        XCTAssertEqual(nextPassSnapshot.actionableStates.count, 1)
        XCTAssertEqual(nextPassSnapshot.actionableStates.first?.habitID, deferredState.habitID)
        XCTAssertEqual(nextPassSnapshot.actionableStates.first?.status, .pending)
        XCTAssertEqual(nextPassSnapshot.actionableStates.first?.currentPass, 2)
    }

    func testRepeatedDeferralsIncreasePassAndEligibilityBackoff() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        guard let initialState = snapshot.states.first else {
            return XCTFail("Expected a generated daily state.")
        }

        let firstDefer = engine.deferState(
            initialState,
            habit: habit,
            remainingActionableHabits: 2,
            at: Self.todayMorning,
            calendar: Self.calendar
        )
        let secondDefer = engine.deferState(
            firstDefer,
            habit: habit,
            remainingActionableHabits: 1,
            at: Self.todayNineTen,
            calendar: Self.calendar
        )

        XCTAssertEqual(firstDefer.deferCount, 1)
        XCTAssertEqual(firstDefer.currentPass, 2)
        XCTAssertEqual(secondDefer.deferCount, 2)
        XCTAssertEqual(secondDefer.currentPass, 3)
        XCTAssertNotNil(firstDefer.nextEligibleAt)
        XCTAssertNotNil(secondDefer.nextEligibleAt)
        XCTAssertGreaterThan(secondDefer.nextEligibleAt ?? .distantPast, firstDefer.nextEligibleAt ?? .distantPast)
    }

    func testMoreRemainingHabitsDelayResurfacingLonger() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        guard let initialState = snapshot.states.first else {
            return XCTFail("Expected a generated daily state.")
        }

        let shortQueue = engine.deferState(
            initialState,
            habit: habit,
            remainingActionableHabits: 1,
            at: Self.todayMorning,
            calendar: Self.calendar
        )
        let longQueue = engine.deferState(
            initialState,
            habit: habit,
            remainingActionableHabits: 5,
            at: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertLessThan(shortQueue.nextEligibleAt ?? .distantPast, longQueue.nextEligibleAt ?? .distantPast)
    }

    func testEveningHabitStaysDeferredInTheMorningAndResurfacesInTheEvening() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Reset",
            schedule: .daily,
            dailyRhythm: .evening,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let morningSnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        guard let morningState = morningSnapshot.states.first else {
            return XCTFail("Expected a generated daily state.")
        }

        let deferredState = engine.deferState(
            morningState,
            habit: habit,
            remainingActionableHabits: 0,
            at: Self.todayMorning,
            calendar: Self.calendar
        )

        let middaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [deferredState],
            on: Self.todayNoon,
            now: Self.todayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(middaySnapshot.actionableStates.count, 0)
        XCTAssertEqual(middaySnapshot.waitingDeferredStates.first?.status, .deferred)

        let eveningSnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [deferredState],
            on: Self.todaySevenPM,
            now: Self.todaySevenPM,
            calendar: Self.calendar
        )

        XCTAssertEqual(eveningSnapshot.actionableStates.first?.habitID, habit.id)
        XCTAssertEqual(eveningSnapshot.actionableStates.first?.status, .pending)
    }

    func testTimeWindowHabitExpiresAfterWindowCloses() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Meditate",
            timeMode: .timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: 8, minute: 0),
                end: HabitClockTime(hour: 9, minute: 0)
            )),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.tenFifteenMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(snapshot.states.first?.status, .expired)
        XCTAssertFalse(snapshot.actionableStates.contains(where: { $0.habitID == habit.id }))
    }

    func testPassedDailyRhythmDoesNotMarkAnAllDayHabitAsFailed() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Skincare",
            schedule: .daily,
            dailyRhythm: .morning,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.todayMorning,
            now: Self.todayNoon,
            calendar: Self.calendar
        )

        XCTAssertEqual(snapshot.states.first?.status, .pending)
        XCTAssertFalse(snapshot.states.first?.status == .expired)
    }

    func testCustomWeekdayHabitOnlyMaterializesOnSelectedDays() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Journal",
            schedule: .customDays(days: [.monday, .wednesday, .friday]),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let tuesdaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.tuesdayMorning,
            now: Self.tuesdayMorning,
            calendar: Self.calendar
        )
        let wednesdaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.wednesdayMorning,
            now: Self.wednesdayMorning,
            calendar: Self.calendar
        )

        XCTAssertTrue(tuesdaySnapshot.states.isEmpty)
        XCTAssertEqual(wednesdaySnapshot.states.count, 1)
        XCTAssertEqual(wednesdaySnapshot.states.first?.habitID, habit.id)
        XCTAssertEqual(wednesdaySnapshot.states.first?.status, .pending)
    }

    func testMonthlyHabitOnlyMaterializesOnConfiguredDayOfMonth() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Review",
            schedule: .monthly(dayOfMonth: 17),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let matchingDaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.monthlyMatchDay,
            now: Self.monthlyMatchDay,
            calendar: Self.calendar
        )
        let nonMatchingDaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.monthlyNonMatchDay,
            now: Self.monthlyNonMatchDay,
            calendar: Self.calendar
        )

        XCTAssertEqual(matchingDaySnapshot.states.count, 1)
        XCTAssertEqual(matchingDaySnapshot.states.first?.habitID, habit.id)
        XCTAssertTrue(nonMatchingDaySnapshot.states.isEmpty)
    }

    func testDateRangeHabitStopsGeneratingAfterTheRangeEnds() {
        let engine = DailyHabitInstanceEngine()
        let habit = Habit(
            title: "Travel",
            schedule: .specificDateRange(HabitDateRange(
                startDate: Self.rangeStartDay,
                endDate: Self.rangeEndDay
            )),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let finalDaySnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.rangeEndDay,
            now: Self.rangeEndDay,
            calendar: Self.calendar
        )
        let afterRangeSnapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [],
            on: Self.dayAfterRange,
            now: Self.dayAfterRange,
            calendar: Self.calendar
        )

        XCTAssertEqual(finalDaySnapshot.states.count, 1)
        XCTAssertEqual(finalDaySnapshot.states.first?.habitID, habit.id)
        XCTAssertTrue(afterRangeSnapshot.states.isEmpty)
    }

    func testDeferredStateResurfacesWhenItsScoreClearsTheThreshold() {
        let engine = DailyHabitInstanceEngine()
        let orderingEngine = TodayDeckOrderingEngine(rhythmConfiguration: .default)
        let habit = Habit(
            title: "Skincare",
            schedule: .daily,
            timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)),
            dailyRhythm: .morning,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let state = DailyHabitState(
            habitID: habit.id,
            date: Self.todayMorning,
            status: .deferred,
            deferCount: 1,
            lastDeferredAt: Self.todayNineOhTwo,
            deckPriority: 0,
            currentPass: 2,
            nextEligibleAt: Self.todayMorning
        )

        XCTAssertTrue(
            orderingEngine.shouldResurfaceDeferredState(
                state,
                habit: habit,
                activeHabitCount: 1,
                on: Self.todayNineOhFive,
                calendar: Self.calendar
            )
        )

        let snapshot = engine.generateSnapshot(
            for: [habit],
            persistedStates: [state],
            on: Self.todayMorning,
            now: Self.todayNineOhFive,
            calendar: Self.calendar
        )

        XCTAssertEqual(snapshot.actionableStates.first?.habitID, habit.id)
        XCTAssertEqual(snapshot.actionableStates.first?.status, .pending)
    }

    func testLowPriorityDeferredStateDoesNotResurfaceTooEarly() {
        let orderingEngine = TodayDeckOrderingEngine(rhythmConfiguration: .default)
        let habit = Habit(
            title: "Wind down",
            schedule: .daily,
            dailyRhythm: .evening,
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let state = DailyHabitState(
            habitID: habit.id,
            date: Self.todayMorning,
            status: .deferred,
            deferCount: 1,
            lastDeferredAt: Self.todayMorning,
            deckPriority: 0,
            currentPass: 1,
            nextEligibleAt: Self.todayMorning
        )

        XCTAssertFalse(
            orderingEngine.shouldResurfaceDeferredState(
                state,
                habit: habit,
                activeHabitCount: 1,
                on: Self.todayNineOhFive,
                calendar: Self.calendar
            )
        )
    }

    func testStoreUpsertsTodayStateForRelaunch() throws {
        let store = LocalDailyHabitStateStore.inMemory()
        let state = DailyHabitState(
            habitID: UUID(),
            date: Self.todayMorning,
            status: .pending,
            deferCount: 0,
            deckPriority: 42,
            currentPass: 1,
            nextEligibleAt: Self.todayNoon
        )

        try store.upsertState(state)
        let loaded = try store.loadStates()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.habitID, state.habitID)
        XCTAssertEqual(loaded.first?.date, state.date)
        XCTAssertEqual(loaded.first?.deckPriority, 42)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let yesterdayMorning = makeDate(year: 2026, month: 8, day: 15, hour: 9, minute: 0)
    private static let yesterdayNoon = makeDate(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
    private static let todayMorning = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 0)
    private static let todayNineOhTwo = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 2)
    private static let todayNineOhThree = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 3)
    private static let todayNineOhSix = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 6)
    private static let todayNineTen = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 10)
    private static let todayNoon = makeDate(year: 2026, month: 8, day: 16, hour: 12, minute: 0)
    private static let todaySevenPM = makeDate(year: 2026, month: 8, day: 16, hour: 19, minute: 0)
    private static let tenFifteenMorning = makeDate(year: 2026, month: 8, day: 16, hour: 10, minute: 15)
    private static let todayNineOhFive = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 5)
    private static let tuesdayMorning = makeDate(year: 2026, month: 8, day: 18, hour: 9, minute: 0)
    private static let wednesdayMorning = makeDate(year: 2026, month: 8, day: 19, hour: 9, minute: 0)
    private static let monthlyMatchDay = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let monthlyNonMatchDay = makeDate(year: 2026, month: 8, day: 18, hour: 9, minute: 0)
    private static let rangeStartDay = makeDate(year: 2026, month: 8, day: 10, hour: 9, minute: 0)
    private static let rangeEndDay = makeDate(year: 2026, month: 8, day: 12, hour: 9, minute: 0)
    private static let dayAfterRange = makeDate(year: 2026, month: 8, day: 13, hour: 9, minute: 0)

    private static func makeDeckHabits() -> [Habit] {
        [
            Habit(title: "Habit A", schedule: .daily, createdAt: todayMorning, updatedAt: todayMorning),
            Habit(title: "Habit B", schedule: .daily, createdAt: todayMorning, updatedAt: todayMorning),
            Habit(title: "Habit C", schedule: .daily, createdAt: todayMorning, updatedAt: todayMorning)
        ]
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
