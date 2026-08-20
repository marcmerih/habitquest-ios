import Foundation
import XCTest
@testable import HabitQuest

final class HabitQuestLocalDataManagementServiceTests: XCTestCase {
    func testExportSnapshotIncludesLocalState() throws {
        let service = makeService()
        let habit = Habit(
            title: "Read",
            schedule: .daily,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )
        try service.habitRepository.createHabit(habit)
        try service.dailyHabitStateStore.saveStates([
            DailyHabitState(
                habitID: habit.id,
                date: Self.referenceDate,
                status: .completed,
                completedAt: Self.referenceDate,
                deckPriority: 1,
                currentPass: 1
            )
        ])
        try service.completionEventStore.saveEvents([
            CompletionEvent(
                habitID: habit.id,
                timestamp: Self.referenceDate,
                logicalCompletionDate: Self.referenceDate,
                source: .manualHabitAction
            )
        ])
        try service.progressionStore.saveProgression(
            HabitProgressionState(lifetimeXP: 25, lastUpdatedAt: Self.referenceDate)
        )
        try service.achievementStore.saveAchievements([
            HabitAchievement(
                id: "sample",
                title: "Sample",
                detail: "Sample detail",
                symbolName: "star.fill",
                earnedAt: Self.referenceDate
            )
        ])
        try service.notificationPreferencesStore.savePreferences(
            HabitQuestNotificationPreferences(
                isEnabled: true,
                quietHours: NotificationQuietHours(
                    isEnabled: true,
                    start: HabitClockTime(hour: 21),
                    end: HabitClockTime(hour: 7)
                ),
                disabledHabitIDs: []
            )
        )

        let exportURL = try service.exportSnapshot(profileName: "Local member", appearanceMode: .dark, at: Self.referenceDate)
        let data = try Data(contentsOf: exportURL)
        let snapshot = try HabitPersistenceCodec.decoder.decode(HabitQuestLocalDataExportSnapshot.self, from: data)

        XCTAssertEqual(snapshot.profileName, "Local member")
        XCTAssertEqual(snapshot.appearanceMode, .dark)
        XCTAssertEqual(snapshot.habits.count, 1)
        XCTAssertEqual(snapshot.customDaySections.count, 0)
        XCTAssertEqual(snapshot.completionEvents.count, 1)
        XCTAssertEqual(snapshot.dailyHabitStates.count, 1)
        XCTAssertEqual(snapshot.behaviorSummary.currentDailyStreak, 1)
        XCTAssertEqual(snapshot.behaviorSummary.longestDailyStreak, 1)
        XCTAssertEqual(snapshot.behaviorSummary.habitProgress.count, 1)
        XCTAssertEqual(snapshot.progression.lifetimeXP, 25)
        XCTAssertEqual(snapshot.achievements.count, 1)
    }

    func testDeleteAllLocalDataClearsStores() throws {
        let service = makeService()
        let habit = Habit(
            title: "Write",
            schedule: .daily,
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )
        try service.habitRepository.createHabit(habit)
        try service.dailyHabitStateStore.saveStates([
            DailyHabitState(habitID: habit.id, date: Self.referenceDate, status: .pending)
        ])
        try service.completionEventStore.saveEvents([
            CompletionEvent(habitID: habit.id, timestamp: Self.referenceDate, logicalCompletionDate: Self.referenceDate, source: .todayDeckSwipe)
        ])
        try service.progressionStore.saveProgression(HabitProgressionState(lifetimeXP: 10, lastUpdatedAt: Self.referenceDate))
        try service.achievementStore.saveAchievements([
            HabitAchievement(id: "sample", title: "Sample", detail: "Sample detail", symbolName: "star.fill", earnedAt: Self.referenceDate)
        ])
        try service.notificationPreferencesStore.savePreferences(
            HabitQuestNotificationPreferences(
                isEnabled: false,
                quietHours: .default,
                disabledHabitIDs: [habit.id]
            )
        )

        try service.deleteAllLocalData()

        XCTAssertEqual(try service.habitRepository.fetchHabits().count, 0)
        XCTAssertEqual(try service.dailyHabitStateStore.loadStates().count, 0)
        XCTAssertEqual(try service.completionEventStore.loadEvents().count, 0)
        XCTAssertEqual(try service.progressionStore.loadProgression(), .default)
        XCTAssertEqual(try service.achievementStore.loadAchievements().count, 0)
        XCTAssertEqual(try service.notificationPreferencesStore.loadPreferences(), .default)
    }

    private func makeService() -> HabitQuestLocalDataManagementService {
        HabitQuestLocalDataManagementService(
            habitRepository: LocalHabitRepository.inMemory(),
            habitDaySectionStore: LocalHabitDaySectionStore.inMemory(),
            dailyHabitStateStore: LocalDailyHabitStateStore.inMemory(),
            completionEventStore: LocalCompletionEventStore.inMemory(),
            progressionStore: LocalHabitProgressionStore.inMemory(),
            achievementStore: LocalHabitAchievementStore.inMemory(),
            notificationPreferencesStore: LocalNotificationPreferencesStore.inMemory(),
            streakFreezeStore: LocalStreakFreezeStore.inMemory(),
            dateService: FixedDateService(now: Self.referenceDate, calendar: Self.calendar),
            dailyStreakCalculator: DailyStreakCalculator(),
            habitProgressCalculator: HabitProgressCalculator(),
            momentumCalculator: HabitMomentumCalculator()
        )
    }

    private static let referenceDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 8
        components.day = 16
        components.hour = 12
        return components.date ?? Date(timeIntervalSince1970: 0)
    }()

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()
}

private struct FixedDateService: DateProviding {
    let now: Date
    let calendar: Calendar
}
