import Foundation
import XCTest
@testable import HabitQuest

final class DomainLayerTests: XCTestCase {
    func testDailyHabitIsScheduledEveryDay() {
        let habit = Habit(title: "Meditate", createdAt: Self.referenceDate, updatedAt: Self.referenceDate)

        XCTAssertTrue(habit.isScheduled(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertTrue(habit.isScheduled(on: Self.nextDay, calendar: Self.calendar))
    }

    func testWeeklyRecurrenceMatchesConfiguredWeekday() {
        let habit = Habit(
            title: "Gym",
            schedule: .weekly(days: [.monday]),
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isScheduled(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.nextDay, calendar: Self.calendar))
    }

    func testBiWeeklyRecurrenceAlternatesEveryOtherWeek() {
        let createdAt = Self.mondayAugustThird2026
        let habit = Habit(
            title: "Therapy",
            schedule: .biWeekly(days: [.monday]),
            createdAt: createdAt,
            updatedAt: createdAt
        )

        XCTAssertTrue(habit.isScheduled(on: createdAt, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.mondayAugustTenth2026, calendar: Self.calendar))
        XCTAssertTrue(habit.isScheduled(on: Self.mondayAugustSeventeenth2026, calendar: Self.calendar))
    }

    func testMonthlyRecurrenceMatchesConfiguredDayOfMonth() {
        let habit = Habit(
            title: "Pay rent",
            schedule: .monthly(dayOfMonth: 17),
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isScheduled(on: Self.mondayAugustSeventeenth2026, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.tuesdayAugustEighteenth2026, calendar: Self.calendar))
    }

    func testCustomDayRecurrenceMatchesSelectedWeekdays() {
        let habit = Habit(
            title: "Journal",
            schedule: .customDays(days: [.monday, .wednesday, .friday]),
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isScheduled(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.tuesdayAugustEighteenth2026, calendar: Self.calendar))
    }

    func testPausedHabitIsNotActiveEvenWhenScheduled() {
        let habit = Habit(
            title: "Stretch",
            isPaused: true,
            schedule: .daily,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isScheduled(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertFalse(habit.isActive(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertTrue(habit.isPausedHabit())
    }

    func testArchivedHabitIsNotActiveEvenWhenScheduled() {
        let habit = Habit(
            title: "Archive test",
            isArchived: true,
            schedule: .daily,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isScheduled(on: Self.referenceDate, calendar: Self.calendar))
        XCTAssertFalse(habit.isActive(on: Self.referenceDate, calendar: Self.calendar))
    }

    func testSpecificDateRangeIsInclusiveAtBoundaries() {
        let range = HabitDateRange(
            startDate: Self.mondayAugustTenth2026,
            endDate: Self.wednesdayAugustTwelfth2026
        )

        let habit = Habit(
            title: "Travel",
            schedule: .specificDateRange(range),
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertFalse(habit.isScheduled(on: Self.sundayAugustNinth2026, calendar: Self.calendar))
        XCTAssertTrue(habit.isScheduled(on: Self.mondayAugustTenth2026, calendar: Self.calendar))
        XCTAssertTrue(habit.isScheduled(on: Self.wednesdayAugustTwelfth2026, calendar: Self.calendar))
        XCTAssertFalse(habit.isScheduled(on: Self.thursdayAugustThirteenth2026, calendar: Self.calendar))
    }

    func testSpecificTimeModeIsRelevantOnlyAtTheConfiguredTime() {
        let habit = Habit(
            title: "Medication",
            timeMode: .specificTime(HabitClockTime(hour: 9, minute: 30)),
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isCurrentlyRelevant(on: Self.nineThirtyAM, calendar: Self.calendar))
        XCTAssertFalse(habit.isCurrentlyRelevant(on: Self.nineThirtyOneAM, calendar: Self.calendar))
    }

    func testProgressionCalculatorAwardsXPAndLevelsSimply() {
        let calculator = HabitProgressionCalculator()
        let habit = Habit(
            title: "Workout",
            difficulty: 5,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        let baseAward = calculator.award(for: habit)
        XCTAssertEqual(baseAward, 12)

        let state = HabitProgressionState(lifetimeXP: 250, lastUpdatedAt: Self.referenceDate)
        let summary = calculator.summary(from: state)

        XCTAssertEqual(summary.lifetimeXP, 250)
        XCTAssertEqual(summary.currentLevel, 3)
        XCTAssertEqual(summary.xpIntoCurrentLevel, 25)
        XCTAssertEqual(summary.xpRequiredForNextLevel, 150)
        XCTAssertEqual(summary.progressToNextLevel, 0.166666, accuracy: 0.001)
    }

    func testTimeWindowModeIsRelevantWithinWindow() {
        let habit = Habit(
            title: "Study",
            timeMode: .timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: 9, minute: 0),
                end: HabitClockTime(hour: 11, minute: 0)
            )),
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertTrue(habit.isCurrentlyRelevant(on: Self.tenFifteenAM, calendar: Self.calendar))
        XCTAssertFalse(habit.isCurrentlyRelevant(on: Self.noon, calendar: Self.calendar))
    }

    func testDailyRhythmIsPreserved() {
        let habit = Habit(
            title: "Morning walk",
            dailyRhythm: .morning,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        XCTAssertEqual(habit.dailyRhythm, .morning)
    }

    func testMorningRhythmBecomesMoreRelevantTowardTheEndOfTheMorningWindow() {
        let configuration = DailyRhythmConfiguration.default

        let earlyMorning = configuration.priorityScore(for: .morning, at: Self.morningEarly, calendar: Self.calendar)
        let lateMorning = configuration.priorityScore(for: .morning, at: Self.morningLate, calendar: Self.calendar)

        XCTAssertLessThan(earlyMorning, lateMorning)
    }

    func testEveningRhythmDoesNotOutrankAnytimeInTheMorning() {
        let configuration = DailyRhythmConfiguration.default

        let eveningScore = configuration.priorityScore(for: .evening, at: Self.morningEarly, calendar: Self.calendar)
        let anytimeScore = configuration.priorityScore(for: .anytime, at: Self.morningEarly, calendar: Self.calendar)

        XCTAssertLessThan(eveningScore, anytimeScore)
    }

    func testExplicitTimePriorityOutranksBroadRhythmMetadata() {
        let engine = TodayDeckOrderingEngine(rhythmConfiguration: .default)

        let explicitHabit = Habit(
            title: "Skincare",
            timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)),
            dailyRhythm: .evening,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )
        let anytimeHabit = Habit(
            title: "Hydrate",
            dailyRhythm: .anytime,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        let states = [
            DailyHabitState(habitID: anytimeHabit.id, date: Self.morningEarly, deckPriority: 0),
            DailyHabitState(habitID: explicitHabit.id, date: Self.morningEarly, deckPriority: 0)
        ]

        let ordered = engine.orderedStates(
            states,
            habits: [anytimeHabit, explicitHabit],
            on: Self.morningEarly,
            calendar: Self.calendar
        )

        XCTAssertEqual(ordered.first?.habitID, explicitHabit.id)
    }

    func testEqualPriorityHabitsUseADeterministicTieBreaker() {
        let engine = TodayDeckOrderingEngine(rhythmConfiguration: .default)
        let earlierHabit = Habit(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "Alpha",
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )
        let laterHabit = Habit(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "Beta",
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )

        let states = [
            DailyHabitState(habitID: laterHabit.id, date: Self.morningEarly, deckPriority: 0),
            DailyHabitState(habitID: earlierHabit.id, date: Self.morningEarly, deckPriority: 0)
        ]

        let ordered = engine.orderedStates(
            states,
            habits: [laterHabit, earlierHabit],
            on: Self.morningEarly,
            calendar: Self.calendar
        )

        XCTAssertEqual(ordered.first?.habitID, earlierHabit.id)
    }

    func testDefaultCreationDraftBuildsSimpleDailyHabit() {
        let draft = HabitCreationDraft(now: Self.referenceDate, calendar: Self.calendar)

        XCTAssertEqual(draft.schedule, .daily)
        XCTAssertEqual(draft.timeMode, .allDay)
        XCTAssertEqual(draft.dailyRhythm, .anytime)
        XCTAssertFalse(draft.remindersEnabled)
        XCTAssertFalse(draft.difficultyEnabled)
    }

    func testCreationDraftConvertsSelectedWeekdaysIntoSchedule() {
        var draft = HabitCreationDraft(now: Self.referenceDate, calendar: Self.calendar)
        draft.title = "Gym"
        draft.prepareForScheduleChange(to: .weekly, now: Self.referenceDate, calendar: Self.calendar)
        draft.selectedWeekdays = [.monday, .wednesday, .friday]
        draft.prepareForTimeModeChange(to: .specificTime, now: Self.referenceDate, calendar: Self.calendar)

        let habit = draft.makeHabit(now: Self.referenceDate, calendar: Self.calendar)

        XCTAssertEqual(habit.schedule, .weekly(days: [.monday, .wednesday, .friday]))
        XCTAssertEqual(habit.timeMode, .specificTime(HabitClockTime(hour: 9, minute: 0)))
        XCTAssertEqual(habit.colorHex, HabitAccentChoice.amber.hex)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let referenceDate = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let nextDay = makeDate(year: 2026, month: 8, day: 18, hour: 9, minute: 0)
    private static let mondayAugustThird2026 = makeDate(year: 2026, month: 8, day: 3, hour: 9, minute: 0)
    private static let mondayAugustTenth2026 = makeDate(year: 2026, month: 8, day: 10, hour: 9, minute: 0)
    private static let mondayAugustSeventeenth2026 = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let tuesdayAugustEighteenth2026 = makeDate(year: 2026, month: 8, day: 18, hour: 9, minute: 0)
    private static let wednesdayAugustTwelfth2026 = makeDate(year: 2026, month: 8, day: 12, hour: 9, minute: 0)
    private static let thursdayAugustThirteenth2026 = makeDate(year: 2026, month: 8, day: 13, hour: 9, minute: 0)
    private static let sundayAugustNinth2026 = makeDate(year: 2026, month: 8, day: 9, hour: 9, minute: 0)
    private static let morningEarly = makeDate(year: 2026, month: 8, day: 17, hour: 8, minute: 10)
    private static let morningLate = makeDate(year: 2026, month: 8, day: 17, hour: 10, minute: 50)
    private static let nineThirtyAM = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 30)
    private static let nineThirtyOneAM = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 31)
    private static let tenFifteenAM = makeDate(year: 2026, month: 8, day: 17, hour: 10, minute: 15)
    private static let noon = makeDate(year: 2026, month: 8, day: 17, hour: 12, minute: 0)

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
