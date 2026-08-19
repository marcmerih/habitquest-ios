import Foundation

struct HabitAchievement: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let earnedAt: Date
}

struct HabitMilestoneEvaluator {
    private let habitProgressCalculator = HabitProgressCalculator()
    private let momentumCalculator = HabitMomentumCalculator()
    private let dailyStreakCalculator = DailyStreakCalculator()
    private let progressionCalculator = HabitProgressionCalculator()

    func evaluate(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState],
        progression: HabitProgressionState,
        earnedAchievementIDs: Set<String> = [],
        at date: Date,
        calendar: Calendar = .current
    ) -> [HabitAchievement] {
        let completionCount = completionEvents.count
        let dailyStreak = dailyStreakCalculator.summary(
            for: habits,
            states: dailyStates,
            completionEvents: completionEvents,
            upTo: date,
            calendar: calendar
        )
        let momentum = momentumCalculator.summary(
            for: habits,
            completionEvents: completionEvents,
            upTo: date,
            calendar: calendar
        )
        let habitProgressSummaries = habitProgressCalculator.summaries(
            for: habits,
            completionEvents: completionEvents,
            upTo: date,
            calendar: calendar
        )
        let progressionSummary = progressionCalculator.summary(from: progression)

        var awards: [HabitAchievement] = []

        appendIfNeeded(
            id: "firstHabitCompleted",
            title: "First habit completed",
            detail: "You started moving with your first completion.",
            symbolName: "checkmark.circle.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards,
            condition: completionCount >= 1
        )

        appendIfNeeded(
            id: "firstFullDayCompleted",
            title: "First full day",
            detail: "You completed everything required for a day.",
            symbolName: "sun.max.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards,
            condition: dailyStreak.currentDailyStreak >= 1
        )

        for threshold in [7, 30] {
            appendIfNeeded(
                id: "dailyStreak.\(threshold)",
                title: "\(threshold)-day consistency",
                detail: "You kept a calm run of complete days going.",
                symbolName: threshold == 7 ? "7.circle.fill" : "calendar.circle.fill",
                at: date,
                earnedAchievementIDs: earnedAchievementIDs,
                into: &awards,
                condition: dailyStreak.longestDailyStreak >= threshold
            )
        }

        appendIfNeeded(
            id: "momentum.30.80",
            title: "Momentum milestone",
            detail: "Your recent consistency held strong across the last 30 days.",
            symbolName: "waveform.path.ecg",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards,
            condition: momentum.recentHistory.count >= 30 && momentum.currentMomentum >= 80
        )

        for threshold in [50, 100] {
            appendIfNeeded(
                id: "totalCompletions.\(threshold)",
                title: "\(threshold) completions",
                detail: "HabitQuest noticed a new layer of steady follow-through.",
                symbolName: "checklist",
                at: date,
                earnedAchievementIDs: earnedAchievementIDs,
                into: &awards,
                condition: completionCount >= threshold
            )
        }

        for threshold in [7, 30] {
            for habit in habits {
                guard let progress = habitProgressSummaries[habit.id] else {
                    continue
                }

                appendIfNeeded(
                    id: "habitStreak.\(habit.id.uuidString).\(threshold)",
                    title: "\(habit.title) streak",
                    detail: "You kept \(habit.title.lowercased()) going for \(threshold) scheduled occurrences.",
                    symbolName: "flame.fill",
                    at: date,
                    earnedAchievementIDs: earnedAchievementIDs,
                    into: &awards,
                    condition: progress.longestStreak >= threshold
                )
            }
        }

        for level in [2, 5, 10] {
            appendIfNeeded(
                id: "progressionLevel.\(level)",
                title: "Level \(level)",
                detail: "Your progression reached a new calm milestone.",
                symbolName: "sparkles",
                at: date,
                earnedAchievementIDs: earnedAchievementIDs,
                into: &awards,
                condition: progressionSummary.currentLevel >= level
            )
        }

        return awards
    }

    private func appendIfNeeded(
        id: String,
        title: String,
        detail: String,
        symbolName: String,
        at date: Date,
        earnedAchievementIDs: Set<String>,
        into awards: inout [HabitAchievement],
        condition: Bool
    ) {
        guard condition, !earnedAchievementIDs.contains(id) else {
            return
        }

        awards.append(
            HabitAchievement(
                id: id,
                title: title,
                detail: detail,
                symbolName: symbolName,
                earnedAt: date
            )
        )
    }
}
