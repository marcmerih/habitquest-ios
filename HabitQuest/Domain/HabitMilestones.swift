import Foundation

struct HabitAchievement: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let earnedAt: Date
}

struct HabitAchievementDefinition: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let sortOrder: Int
}

enum HabitAchievementCatalog {
    static func definitions(for habits: [Habit]) -> [HabitAchievementDefinition] {
        let activeHabits = habits
            .filter { !$0.isArchived }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        var definitions = globalDefinitions
        var sortOrder = definitions.count

        for habit in activeHabits {
            for threshold in habitStreakThresholds {
                definitions.append(
                    HabitAchievementDefinition(
                        id: "habitStreak.\(habit.id.uuidString).\(threshold)",
                        title: "\(habit.title) streak",
                        detail: "You kept \(habit.title.lowercased()) going for \(threshold) scheduled completions.",
                        symbolName: "flame.fill",
                        sortOrder: sortOrder
                    )
                )
                sortOrder += 1
            }
        }

        return definitions.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.id < rhs.id
            }

            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private static let globalDefinitions: [HabitAchievementDefinition] = {
        var definitions: [HabitAchievementDefinition] = []
        var sortOrder = 0

        func append(
            _ id: String,
            _ title: String,
            _ detail: String,
            _ symbolName: String
        ) {
            definitions.append(
                HabitAchievementDefinition(
                    id: id,
                    title: title,
                    detail: detail,
                    symbolName: symbolName,
                    sortOrder: sortOrder
                )
            )
            sortOrder += 1
        }

        func appendSeries(
            prefix: String,
            thresholds: [Int],
            symbolName: String,
            title: (Int) -> String,
            detail: (Int) -> String
        ) {
            for threshold in thresholds {
                append(
                    "\(prefix).\(threshold)",
                    title(threshold),
                    detail(threshold),
                    symbolName
                )
            }
        }

        append(
            "firstHabitCompleted",
            "First habit completed",
            "You started moving with your first completion.",
            "checkmark.circle.fill"
        )

        append(
            "firstFullDayCompleted",
            "First full day",
            "You completed everything required for a day.",
            "sun.max.fill"
        )

        appendSeries(
            prefix: "dailyStreak",
            thresholds: [1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 90, 120, 180, 365],
            symbolName: "sun.max.fill",
            title: { "\($0)-day consistency" },
            detail: { "You kept a calm streak of \($0) complete days going." }
        )

        appendSeries(
            prefix: "completionTotal",
            thresholds: [1, 3, 5, 10, 15, 20, 25, 35, 50, 75, 100, 150, 200, 300, 500],
            symbolName: "checklist",
            title: { "\($0) completions" },
            detail: { _ in "HabitQuest noticed a new layer of steady follow-through." }
        )

        appendSeries(
            prefix: "momentum",
            thresholds: [10, 20, 30, 40, 50, 60, 70, 80, 85, 90, 95, 98, 100],
            symbolName: "waveform.path.ecg",
            title: { "\($0) Momentum" },
            detail: { threshold in "Your recent consistency held strong enough to reach \(threshold) Momentum." }
        )

        appendSeries(
            prefix: "level",
            thresholds: Array(2...25),
            symbolName: "sparkles",
            title: { "Level \($0)" },
            detail: { _ in "Your progression reached a new calm milestone." }
        )

        appendSeries(
            prefix: "habitCount",
            thresholds: [1, 3, 5, 7, 10, 12, 15, 20],
            symbolName: "square.grid.2x2",
            title: { "\($0) active habits" },
            detail: { "You built a steadier habit system with \($0) active habits." }
        )

        appendSeries(
            prefix: "categoryCount",
            thresholds: [1, 3, 5, 8, 10],
            symbolName: "tag.fill",
            title: { "\($0) categories" },
            detail: { "Your habits now span \($0) different categories." }
        )

        appendSeries(
            prefix: "rhythmCount",
            thresholds: [1, 2, 3, 4],
            symbolName: "clock.fill",
            title: { "\($0) rhythms" },
            detail: { "Your habits now live across \($0) daily rhythms." }
        )

        appendSeries(
            prefix: "weekdayCount",
            thresholds: [1, 3, 5, 7],
            symbolName: "calendar",
            title: { "\($0) weekdays" },
            detail: { "You've completed habits on \($0) different weekdays." }
        )

        appendSeries(
            prefix: "monthCount",
            thresholds: [1, 2, 3, 6, 12],
            symbolName: "calendar.badge.clock",
            title: { "\($0) active months" },
            detail: { "Your habit history now stretches across \($0) active months." }
        )

        appendSeries(
            prefix: "completionRate",
            thresholds: [25, 40, 50, 60, 70, 80, 90, 95, 100],
            symbolName: "chart.line.uptrend.xyaxis",
            title: { "\($0)% completion" },
            detail: { "Your overall completion rate reached \($0)%." }
        )

        return definitions
    }()

    static let habitStreakThresholds: [Int] = [3, 5, 7, 10, 14, 21, 30, 45, 60, 90]
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
        let metrics = AchievementMetrics(
            habits: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            progression: progression,
            date: date,
            calendar: calendar,
            dailyStreakCalculator: dailyStreakCalculator,
            momentumCalculator: momentumCalculator,
            habitProgressCalculator: habitProgressCalculator,
            progressionCalculator: progressionCalculator
        )

        var awards: [HabitAchievement] = []

        appendIfNeeded(
            id: "firstHabitCompleted",
            title: "First habit completed",
            detail: "You started moving with your first completion.",
            symbolName: "checkmark.circle.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards,
            condition: metrics.completionCount >= 1
        )

        appendIfNeeded(
            id: "firstFullDayCompleted",
            title: "First full day",
            detail: "You completed everything required for a day.",
            symbolName: "sun.max.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards,
            condition: metrics.currentDailyStreak >= 1
        )

        appendSeries(
            prefix: "dailyStreak",
            thresholds: [1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 90, 120, 180, 365],
            metric: metrics.longestDailyStreak,
            title: { "\($0)-day consistency" },
            detail: { "You kept a calm streak of \($0) complete days going." },
            symbolName: "sun.max.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "completionTotal",
            thresholds: [1, 3, 5, 10, 15, 20, 25, 35, 50, 75, 100, 150, 200, 300, 500],
            metric: metrics.completionCount,
            title: { "\($0) completions" },
            detail: { _ in "HabitQuest noticed a new layer of steady follow-through." },
            symbolName: "checklist",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "momentum",
            thresholds: [10, 20, 30, 40, 50, 60, 70, 80, 85, 90, 95, 98, 100],
            metric: metrics.currentMomentum,
            title: { "\($0) Momentum" },
            detail: { "Your recent consistency held strong enough to reach \($0) Momentum." },
            symbolName: "waveform.path.ecg",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "level",
            thresholds: Array(2...25),
            metric: metrics.currentLevel,
            title: { "Level \($0)" },
            detail: { _ in "Your progression reached a new calm milestone." },
            symbolName: "sparkles",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "habitCount",
            thresholds: [1, 3, 5, 7, 10, 12, 15, 20],
            metric: metrics.activeHabitCount,
            title: { "\($0) active habits" },
            detail: { "You built a steadier habit system with \($0) active habits." },
            symbolName: "square.grid.2x2",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "categoryCount",
            thresholds: [1, 3, 5, 8, 10],
            metric: metrics.categoryCount,
            title: { "\($0) categories" },
            detail: { "Your habits now span \($0) different categories." },
            symbolName: "tag.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "rhythmCount",
            thresholds: [1, 2, 3, 4],
            metric: metrics.rhythmCount,
            title: { "\($0) rhythms" },
            detail: { "Your habits now live across \($0) daily rhythms." },
            symbolName: "clock.fill",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "weekdayCount",
            thresholds: [1, 3, 5, 7],
            metric: metrics.completionWeekdayCount,
            title: { "\($0) weekdays" },
            detail: { "You've completed habits on \($0) different weekdays." },
            symbolName: "calendar",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "monthCount",
            thresholds: [1, 2, 3, 6, 12],
            metric: metrics.activeMonthCount,
            title: { "\($0) active months" },
            detail: { "Your habit history now stretches across \($0) active months." },
            symbolName: "calendar.badge.clock",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        appendSeries(
            prefix: "completionRate",
            thresholds: [25, 40, 50, 60, 70, 80, 90, 95, 100],
            metric: metrics.completionRate,
            title: { "\($0)% completion" },
            detail: { "Your overall completion rate reached \($0)%." },
            symbolName: "chart.line.uptrend.xyaxis",
            at: date,
            earnedAchievementIDs: earnedAchievementIDs,
            into: &awards
        )

        for habit in metrics.activeHabits {
            guard let progress = metrics.habitProgressSummaries[habit.id] else {
                continue
            }

            appendSeries(
                prefix: "habitStreak.\(habit.id.uuidString)",
                thresholds: HabitAchievementCatalog.habitStreakThresholds,
                metric: progress.longestStreak,
                title: { _ in "\(habit.title) streak" },
                detail: { threshold in "You kept \(habit.title.lowercased()) going for \(threshold) scheduled completions." },
                symbolName: "flame.fill",
                at: date,
                earnedAchievementIDs: earnedAchievementIDs,
                into: &awards
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

    private func appendSeries(
        prefix: String,
        thresholds: [Int],
        metric: Int,
        title: (Int) -> String,
        detail: (Int) -> String,
        symbolName: String,
        at date: Date,
        earnedAchievementIDs: Set<String>,
        into awards: inout [HabitAchievement]
    ) {
        for threshold in thresholds {
            appendIfNeeded(
                id: "\(prefix).\(threshold)",
                title: title(threshold),
                detail: detail(threshold),
                symbolName: symbolName,
                at: date,
                earnedAchievementIDs: earnedAchievementIDs,
                into: &awards,
                condition: metric >= threshold
            )
        }
    }
}

private struct AchievementMetrics {
    let activeHabits: [Habit]
    let completionCount: Int
    let currentDailyStreak: Int
    let longestDailyStreak: Int
    let currentMomentum: Int
    let currentLevel: Int
    let activeHabitCount: Int
    let categoryCount: Int
    let rhythmCount: Int
    let completionWeekdayCount: Int
    let activeMonthCount: Int
    let completionRate: Int
    let habitProgressSummaries: [UUID: HabitProgressSummary]

    init(
        habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState],
        progression: HabitProgressionState,
        date: Date,
        calendar: Calendar,
        dailyStreakCalculator: DailyStreakCalculator,
        momentumCalculator: HabitMomentumCalculator,
        habitProgressCalculator: HabitProgressCalculator,
        progressionCalculator: HabitProgressionCalculator
    ) {
        let activeHabits = habits.filter { !$0.isArchived }
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

        let completionCount = completionEvents.count
        let completedStates = dailyStates.filter { $0.status == .completed }.count
        let completionRate = dailyStates.isEmpty
            ? 0
            : Int(((Double(completedStates) / Double(dailyStates.count)) * 100).rounded())

        let categoryCount = Set(activeHabits.compactMap { habit -> String? in
            guard let category = habit.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty else {
                return nil
            }
            return category.lowercased()
        }).count

        let rhythmCount = Set(activeHabits.map(\.dailyRhythm)).count
        let activeHabitCount = activeHabits.filter { !$0.isPaused }.count
        let completionWeekdayCount = Set(completionEvents.map { calendar.component(.weekday, from: $0.logicalCompletionDate) }).count
        let activeMonthCount = Set(completionEvents.map {
            let components = calendar.dateComponents([.year, .month], from: $0.logicalCompletionDate)
            return "\(components.year ?? 0)-\(components.month ?? 0)"
        }).count

        self.activeHabits = activeHabits
        self.completionCount = completionCount
        self.currentDailyStreak = dailyStreak.currentDailyStreak
        self.longestDailyStreak = dailyStreak.longestDailyStreak
        self.currentMomentum = Int(momentum.currentMomentum.rounded())
        self.currentLevel = progressionSummary.currentLevel
        self.activeHabitCount = activeHabitCount
        self.categoryCount = categoryCount
        self.rhythmCount = rhythmCount
        self.completionWeekdayCount = completionWeekdayCount
        self.activeMonthCount = activeMonthCount
        self.completionRate = completionRate
        self.habitProgressSummaries = habitProgressSummaries
    }
}
