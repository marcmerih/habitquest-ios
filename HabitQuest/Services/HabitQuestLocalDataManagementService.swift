import Foundation

enum HabitQuestLocalDataManagementError: LocalizedError, Sendable {
    case exportFailed(underlying: Error)
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "HabitQuest could not export your local data."
        case .deleteFailed:
            return "HabitQuest could not delete your local data."
        }
    }
}

struct HabitQuestLocalDataExportSnapshot: Codable, Sendable {
    let exportedAt: Date
    let profileName: String
    let appearanceMode: HabitQuestAppearanceMode
    let habits: [Habit]
    let customDaySections: [HabitDaySection]
    let completionEvents: [CompletionEvent]
    let dailyHabitStates: [DailyHabitState]
    let behaviorSummary: HabitQuestLocalDataBehaviorSummary
    let progression: HabitProgressionState
    let achievements: [HabitAchievement]
    let notificationPreferences: HabitQuestNotificationPreferences
}

struct HabitQuestLocalDataBehaviorSummary: Codable, Sendable {
    let rangeStart: Date
    let rangeEnd: Date
    let currentDailyStreak: Int
    let longestDailyStreak: Int
    let momentum: HabitQuestMomentumExportSummary
    let habitProgress: [HabitQuestHabitProgressExportSummary]
}

struct HabitQuestMomentumExportSummary: Codable, Sendable {
    let current: Double
    let previous: Double
    let trendDelta: Double
    let trendDirection: MomentumTrend.Direction
}

struct HabitQuestHabitProgressExportSummary: Codable, Sendable {
    let habitID: UUID
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let recentConsistencyPercentage: Double?
    let lifetimeConsistencyPercentage: Double?
    let scheduledOccurrenceCount: Int
}

struct HabitQuestLocalDataManagementService {
    let habitRepository: LocalHabitRepository
    let habitDaySectionStore: LocalHabitDaySectionStore
    let dailyHabitStateStore: LocalDailyHabitStateStore
    let completionEventStore: LocalCompletionEventStore
    let progressionStore: LocalHabitProgressionStore
    let achievementStore: LocalHabitAchievementStore
    let notificationPreferencesStore: LocalNotificationPreferencesStore
    let dateService: any DateProviding
    let dailyStreakCalculator: DailyStreakCalculator
    let habitProgressCalculator: HabitProgressCalculator
    let momentumCalculator: HabitMomentumCalculator

    func exportSnapshot(
        profileName: String,
        appearanceMode: HabitQuestAppearanceMode,
        at timestamp: Date = .now
    ) throws -> URL {
        do {
            let habits = try habitRepository.fetchHabits()
            let customDaySections = try habitDaySectionStore.loadSections()
            let completionEvents = try completionEventStore.loadEvents()
            let dailyHabitStates = try dailyHabitStateStore.loadStates()

            let snapshot = HabitQuestLocalDataExportSnapshot(
                exportedAt: timestamp,
                profileName: profileName,
                appearanceMode: appearanceMode,
                habits: habits,
                customDaySections: customDaySections,
                completionEvents: completionEvents,
                dailyHabitStates: dailyHabitStates,
                behaviorSummary: behaviorSummary(
                    habits: habits,
                    completionEvents: completionEvents,
                    dailyHabitStates: dailyHabitStates,
                    at: timestamp
                ),
                progression: try progressionStore.loadProgression(),
                achievements: try achievementStore.loadAchievements(),
                notificationPreferences: try notificationPreferencesStore.loadPreferences()
            )

            let exportURL = Self.exportURL(for: timestamp)
            let data = try HabitPersistenceCodec.encoder.encode(snapshot)
            try data.write(to: exportURL, options: Data.WritingOptions.atomic)
            return exportURL
        } catch {
            throw HabitQuestLocalDataManagementError.exportFailed(underlying: error)
        }
    }

    func deleteAllLocalData() throws {
        do {
            try habitRepository.reset()
            try habitDaySectionStore.reset()
            try completionEventStore.reset()
            try dailyHabitStateStore.reset()
            try progressionStore.reset()
            try achievementStore.reset()
            try notificationPreferencesStore.reset()
        } catch {
            throw HabitQuestLocalDataManagementError.deleteFailed(underlying: error)
        }
    }

    private func behaviorSummary(
        habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyHabitStates: [DailyHabitState],
        at timestamp: Date
    ) -> HabitQuestLocalDataBehaviorSummary {
        let calendar = dateService.calendar
        let windowStart = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: timestamp)) ?? timestamp
        let range = windowStart...timestamp

        let dailySummary = dailyStreakCalculator.summary(
            for: habits,
            states: dailyHabitStates,
            completionEvents: completionEvents,
            upTo: timestamp,
            calendar: calendar
        )

        let momentum = momentumCalculator.summary(
            for: habits,
            completionEvents: completionEvents,
            upTo: timestamp,
            calendar: calendar,
            windowDays: 30
        )

        let habitProgress = habitProgressCalculator.summaries(
            for: habits,
            completionEvents: completionEvents,
            upTo: timestamp,
            calendar: calendar
        ).map { habitID, summary in
            HabitQuestHabitProgressExportSummary(
                habitID: habitID,
                currentStreak: summary.currentStreak,
                longestStreak: summary.longestStreak,
                totalCompletions: summary.totalCompletions,
                recentConsistencyPercentage: summary.recentConsistencyPercentage,
                lifetimeConsistencyPercentage: summary.lifetimeConsistencyPercentage,
                scheduledOccurrenceCount: summary.scheduledOccurrenceCount
            )
        }
        .sorted { $0.habitID.uuidString < $1.habitID.uuidString }

        return HabitQuestLocalDataBehaviorSummary(
            rangeStart: range.lowerBound,
            rangeEnd: range.upperBound,
            currentDailyStreak: dailySummary.currentDailyStreak,
            longestDailyStreak: dailySummary.longestDailyStreak,
            momentum: HabitQuestMomentumExportSummary(
                current: momentum.currentMomentum,
                previous: momentum.previousMomentum,
                trendDelta: momentum.trend.delta,
                trendDirection: momentum.trend.direction
            ),
            habitProgress: habitProgress
        )
    }

    private static func exportURL(for timestamp: Date) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let fileName = "HabitQuest-Export-\(formatter.string(from: timestamp)).json"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
}
