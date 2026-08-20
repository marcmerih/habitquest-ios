import Foundation

struct HabitStreakCalculator {
    func streak(for habitID: UUID?, from events: [CompletionEvent], upTo date: Date, calendar: Calendar = .current) -> Int {
        let filteredEvents = events
            .filter { habitID == nil || $0.habitID == habitID }
            .sorted {
                if $0.logicalCompletionDate == $1.logicalCompletionDate {
                    return $0.timestamp < $1.timestamp
                }
                return $0.logicalCompletionDate < $1.logicalCompletionDate
            }

        let completedDays = Set(filteredEvents.map { calendar.startOfDay(for: $0.logicalCompletionDate) })
        var streak = 0
        var cursor = calendar.startOfDay(for: date)

        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }
}

struct HabitProgressSummary: Equatable, Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let recentConsistencyPercentage: Double?
    let lifetimeConsistencyPercentage: Double?
    let scheduledOccurrenceCount: Int
}

struct HabitProgressCalculator {
    func summary(
        for habit: Habit,
        completionEvents: [CompletionEvent],
        upTo date: Date,
        calendar: Calendar = .current,
        recentWindowSize: Int = 30
    ) -> HabitProgressSummary {
        let cutoffDay = calendar.startOfDay(for: date)
        let scheduledOccurrences = scheduledOccurrences(for: habit, upTo: cutoffDay, calendar: calendar)
        let completedDays = completedDays(
            from: completionEvents,
            habitID: habit.id,
            upTo: cutoffDay,
            calendar: calendar
        )
        let completedScheduledOccurrences = scheduledOccurrences.filter { completedDays.contains($0) }
        let recentScheduledOccurrences = Array(scheduledOccurrences.suffix(recentWindowSize))
        let recentCompletedCount = recentScheduledOccurrences.filter { completedDays.contains($0) }.count

        return HabitProgressSummary(
            currentStreak: currentStreak(
                scheduledOccurrences: scheduledOccurrences,
                completedDays: completedDays
            ),
            longestStreak: longestStreak(
                scheduledOccurrences: scheduledOccurrences,
                completedDays: completedDays
            ),
            totalCompletions: completedScheduledOccurrences.count,
            recentConsistencyPercentage: consistencyPercentage(
                completedCount: recentCompletedCount,
                totalCount: recentScheduledOccurrences.count
            ),
            lifetimeConsistencyPercentage: consistencyPercentage(
                completedCount: completedScheduledOccurrences.count,
                totalCount: scheduledOccurrences.count
            ),
            scheduledOccurrenceCount: scheduledOccurrences.count
        )
    }

    func summaries(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        upTo date: Date,
        calendar: Calendar = .current,
        recentWindowSize: Int = 30
    ) -> [UUID: HabitProgressSummary] {
        let groupedEvents = Dictionary(grouping: completionEvents) { $0.habitID }

        return Dictionary(uniqueKeysWithValues: habits.map { habit in
            (
                habit.id,
                summary(
                    for: habit,
                    completionEvents: groupedEvents[habit.id] ?? [],
                    upTo: date,
                    calendar: calendar,
                    recentWindowSize: recentWindowSize
                )
            )
        })
    }

    private func scheduledOccurrences(for habit: Habit, upTo date: Date, calendar: Calendar) -> [Date] {
        let startDay = calendar.startOfDay(for: habit.createdAt)
        let cutoffDay = calendar.startOfDay(for: date)

        guard startDay <= cutoffDay else {
            return []
        }

        var occurrences: [Date] = []
        var cursor = startDay

        while cursor <= cutoffDay {
            if habit.isScheduled(on: cursor, calendar: calendar) {
                occurrences.append(cursor)
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        return occurrences
    }

    private func completedDays(
        from completionEvents: [CompletionEvent],
        habitID: UUID,
        upTo date: Date,
        calendar: Calendar
    ) -> Set<Date> {
        let cutoffDay = calendar.startOfDay(for: date)

        return Set(
            completionEvents
                .filter { $0.habitID == habitID }
                .filter { calendar.startOfDay(for: $0.logicalCompletionDate) <= cutoffDay }
                .map { calendar.startOfDay(for: $0.logicalCompletionDate) }
        )
    }

    private func currentStreak(
        scheduledOccurrences: [Date],
        completedDays: Set<Date>
    ) -> Int {
        var streak = 0

        for day in scheduledOccurrences.reversed() {
            if completedDays.contains(day) {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    private func longestStreak(
        scheduledOccurrences: [Date],
        completedDays: Set<Date>
    ) -> Int {
        var longest = 0
        var current = 0

        for day in scheduledOccurrences {
            if completedDays.contains(day) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    private func consistencyPercentage(completedCount: Int, totalCount: Int) -> Double? {
        guard totalCount > 0 else {
            return nil
        }

        return (Double(completedCount) / Double(totalCount)) * 100
    }
}

struct HabitMomentumCalculator {
    /// Momentum is a rolling habit-behavior score, not a streak.
    ///
    /// The score looks at the last `windowDays` calendar days, calculates a daily
    /// completion ratio for each day that had at least one habit due, then applies a
    /// linearly weighted average where older days count at 50% weight and the newest
    /// day counts at 100% weight.
    ///
    /// This keeps momentum understandable:
    /// - a single imperfect day nudges the score down, but does not collapse it
    /// - sustained completion gradually raises it
    /// - sustained inactivity gradually lowers it
    /// - days with no due habits stay neutral because they are excluded from the average
    func summary(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        upTo date: Date,
        calendar: Calendar = .current,
        windowDays: Int = 30
    ) -> MomentumSummary {
        let safeWindow = max(windowDays, 1)
        let cutoffDay = calendar.startOfDay(for: date)
        let startDay = calendar.date(byAdding: .day, value: -(safeWindow * 2 - 1), to: cutoffDay) ?? cutoffDay

        let history = momentumHistory(
            for: habits,
            completionEvents: completionEvents,
            startDay: startDay,
            endDay: cutoffDay,
            calendar: calendar
        )

        let currentWindow = Array(history.suffix(safeWindow))
        let previousWindow = Array(history.dropLast(currentWindow.count).suffix(safeWindow))

        let currentMomentum = weightedMomentum(for: currentWindow)
        let previousMomentum = weightedMomentum(for: previousWindow)
        let delta = currentMomentum - previousMomentum

        return MomentumSummary(
            currentMomentum: currentMomentum,
            previousMomentum: previousMomentum,
            trend: MomentumTrend(delta: delta),
            recentHistory: currentWindow
        )
    }

    func score(for completionHistory: [Bool]) -> Double {
        let window = Array(completionHistory.suffix(30))
        guard !window.isEmpty else {
            return 0
        }

        let weightedTotal = window.enumerated().reduce(0.0) { partialResult, entry in
            let recencyWeight = 0.5 + (0.5 * Double(entry.offset + 1) / Double(window.count))
            return partialResult + (entry.element ? recencyWeight : 0)
        }

        let maxTotal = window.enumerated().reduce(0.0) { partialResult, entry in
            partialResult + (0.5 + (0.5 * Double(entry.offset + 1) / Double(window.count)))
        }

        return maxTotal == 0 ? 0 : weightedTotal / maxTotal
    }

    private func momentumHistory(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        startDay: Date,
        endDay: Date,
        calendar: Calendar
    ) -> [MomentumHistoryPoint] {
        let activeHabits = habits.filter { !$0.isArchived && !$0.isPaused && $0.createdAt <= endDay }
        let completionLookup = Dictionary(grouping: completionEvents) { calendar.startOfDay(for: $0.logicalCompletionDate) }

        var history: [MomentumHistoryPoint] = []
        var cursor = startDay

        while cursor <= endDay {
            let dueHabits = activeHabits.filter { $0.isScheduled(on: cursor, calendar: calendar) }
            let dueCount = dueHabits.count

            if dueCount == 0 {
                history.append(
                    MomentumHistoryPoint(date: cursor, value: nil, dueCount: 0, completedCount: 0)
                )
            } else {
                let completedIDs = Set(
                    (completionLookup[cursor] ?? [])
                        .map(\.habitID)
                )
                let completedCount = dueHabits.filter { completedIDs.contains($0.id) }.count
                let ratio = (Double(completedCount) / Double(dueCount)) * 100

                history.append(
                    MomentumHistoryPoint(
                        date: cursor,
                        value: ratio,
                        dueCount: dueCount,
                        completedCount: completedCount
                    )
                )
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        return history
    }

private func weightedMomentum(for history: [MomentumHistoryPoint]) -> Double {
        let meaningful = history.compactMap(\.value)
        guard !meaningful.isEmpty else {
            return 0
        }

        let values = meaningful
        let count = values.count

        let weightedTotal = values.enumerated().reduce(0.0) { partialResult, entry in
            let recencyWeight = 0.5 + (0.5 * Double(entry.offset + 1) / Double(count))
            return partialResult + (entry.element * recencyWeight)
        }

        let maxTotal = values.enumerated().reduce(0.0) { partialResult, entry in
            partialResult + (100 * (0.5 + (0.5 * Double(entry.offset + 1) / Double(count))))
        }

        guard maxTotal > 0 else {
            return 0
        }

        return (weightedTotal / maxTotal) * 100
    }
}

struct HabitProgressionState: Codable, Equatable, Sendable {
    var lifetimeXP: Int
    var lastUpdatedAt: Date?

    static let `default` = HabitProgressionState(lifetimeXP: 0, lastUpdatedAt: nil)
}

struct HabitProgressionSummary: Equatable, Sendable {
    let lifetimeXP: Int
    let currentLevel: Int
    let xpIntoCurrentLevel: Int
    let xpRequiredForNextLevel: Int
    let progressToNextLevel: Double
    let lastUpdatedAt: Date?
}

struct HabitProgressionCalculator {
    private let baseCompletionXP = 10
    private let maxDifficultyBonus = 2
    private let startingLevelRequirement = 100
    private let levelStepRequirement = 25

    func award(for habit: Habit) -> Int {
        let difficulty = max(habit.difficulty ?? 0, 0)
        let cappedDifficulty = min(difficulty, 5)
        let difficultyBonus = cappedDifficulty / 2
        return baseCompletionXP + min(difficultyBonus, maxDifficultyBonus)
    }

    func summary(from state: HabitProgressionState) -> HabitProgressionSummary {
        let sanitizedXP = max(state.lifetimeXP, 0)
        let progression = levelProgression(for: sanitizedXP)

        return HabitProgressionSummary(
            lifetimeXP: sanitizedXP,
            currentLevel: progression.currentLevel,
            xpIntoCurrentLevel: progression.xpIntoCurrentLevel,
            xpRequiredForNextLevel: progression.xpRequiredForNextLevel,
            progressToNextLevel: progression.progressToNextLevel,
            lastUpdatedAt: state.lastUpdatedAt
        )
    }

    func state(after awardingXP: Int, to currentState: HabitProgressionState = .default, at timestamp: Date = .now) -> HabitProgressionState {
        var updated = currentState
        updated.lifetimeXP = max(0, currentState.lifetimeXP + max(awardingXP, 0))
        updated.lastUpdatedAt = timestamp
        return updated
    }

    func state(from habits: [Habit], completionEvents: [CompletionEvent]) -> HabitProgressionState {
        let habitByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let totalXP = completionEvents.reduce(0) { partialResult, event in
            guard let habit = habitByID[event.habitID] else {
                return partialResult
            }

            return partialResult + award(for: habit)
        }

        return HabitProgressionState(
            lifetimeXP: totalXP,
            lastUpdatedAt: completionEvents.map(\.timestamp).max()
        )
    }

    private func levelProgression(for lifetimeXP: Int) -> (currentLevel: Int, xpIntoCurrentLevel: Int, xpRequiredForNextLevel: Int, progressToNextLevel: Double) {
        var level = 1
        var remainingXP = lifetimeXP
        var requiredXP = xpRequired(for: level)

        while remainingXP >= requiredXP {
            remainingXP -= requiredXP
            level += 1
            requiredXP = xpRequired(for: level)
        }

        let progress = requiredXP > 0 ? Double(remainingXP) / Double(requiredXP) : 0
        return (level, remainingXP, requiredXP, progress)
    }

    private func xpRequired(for level: Int) -> Int {
        startingLevelRequirement + ((max(level, 1) - 1) * levelStepRequirement)
    }
}

struct MomentumSummary: Equatable, Sendable {
    let currentMomentum: Double
    let previousMomentum: Double
    let trend: MomentumTrend
    let recentHistory: [MomentumHistoryPoint]
}

struct MomentumTrend: Equatable, Sendable {
    enum Direction: String, Codable, CaseIterable, Sendable {
        case rising
        case steady
        case falling
    }

    let delta: Double
    let direction: Direction

    init(delta: Double, threshold: Double = 3) {
        self.delta = delta

        if delta >= threshold {
            direction = .rising
        } else if delta <= -threshold {
            direction = .falling
        } else {
            direction = .steady
        }
    }
}

struct MomentumHistoryPoint: Equatable, Sendable {
    let date: Date
    let value: Double?
    let dueCount: Int
    let completedCount: Int
}

struct DailyStreakSummary: Equatable, Sendable {
    let currentDailyStreak: Int
    let longestDailyStreak: Int
    let lastFullyCompletedDate: Date?
}

struct DailyStreakRules: Equatable, Sendable {
    var graceDays: Int = 0

    init(graceDays: Int = 0) {
        self.graceDays = max(graceDays, 0)
    }
}

struct DailyStreakCalculator {
    private struct DayAssessment {
        enum Status {
            case neutral
            case completed
            case incomplete
        }

        let date: Date
        let status: Status
    }

    func summary(
        for habits: [Habit],
        states: [DailyHabitState],
        completionEvents: [CompletionEvent],
        upTo date: Date,
        calendar: Calendar = .current,
        rules: DailyStreakRules = .init()
    ) -> DailyStreakSummary {
        let cutoffDay = calendar.startOfDay(for: date)
        let excludedHabitIDs = Set(habits.filter { $0.isArchived || $0.isPaused }.map(\.id))

        let filteredStates = states.filter { !excludedHabitIDs.contains($0.habitID) && calendar.startOfDay(for: $0.date) <= cutoffDay }
        let filteredEvents = completionEvents.filter { !excludedHabitIDs.contains($0.habitID) && calendar.startOfDay(for: $0.logicalCompletionDate) <= cutoffDay }

        let completionKeys = Set(filteredEvents.map { completionKey(habitID: $0.habitID, date: calendar.startOfDay(for: $0.logicalCompletionDate)) })

        let dayAssessments = buildDayAssessments(
            states: filteredStates,
            completionKeys: completionKeys,
            upTo: cutoffDay,
            calendar: calendar
        )

        guard !dayAssessments.isEmpty else {
            return DailyStreakSummary(currentDailyStreak: 0, longestDailyStreak: 0, lastFullyCompletedDate: nil)
        }

        let currentDailyStreak = currentStreak(
            dayAssessments: dayAssessments,
            upTo: cutoffDay,
            calendar: calendar,
            rules: rules
        )

        let longestAndLast = longestStreak(
            dayAssessments: dayAssessments,
            rules: rules
        )

        return DailyStreakSummary(
            currentDailyStreak: currentDailyStreak,
            longestDailyStreak: longestAndLast.longest,
            lastFullyCompletedDate: longestAndLast.lastCompletedDate
        )
    }

    func currentDailyStreak(
        for habits: [Habit],
        states: [DailyHabitState],
        completionEvents: [CompletionEvent],
        upTo date: Date,
        calendar: Calendar = .current,
        rules: DailyStreakRules = .init()
    ) -> Int {
        summary(
            for: habits,
            states: states,
            completionEvents: completionEvents,
            upTo: date,
            calendar: calendar,
            rules: rules
        ).currentDailyStreak
    }

    private func buildDayAssessments(
        states: [DailyHabitState],
        completionKeys: Set<String>,
        upTo date: Date,
        calendar: Calendar
    ) -> [DayAssessment] {
        let statesByDay = Dictionary(grouping: states) { calendar.startOfDay(for: $0.date) }
        let allDays = statesByDay.keys.sorted()

        return allDays.compactMap { day -> DayAssessment? in
            guard day <= date else {
                return nil
            }

            let dayStates = statesByDay[day] ?? []
            guard !dayStates.isEmpty else {
                return DayAssessment(date: day, status: .neutral)
            }

            if dayStates.contains(where: { $0.streakFreezeAppliedAt != nil }) {
                return DayAssessment(date: day, status: .completed)
            }

            let relevantStates = dayStates
                .filter { state in
                    let key = completionKey(habitID: state.habitID, date: day)
                    return completionKeys.contains(key) || state.status == .completed
                }

            let completedCount = relevantStates.count
            let totalCount = dayStates.count

            if totalCount == 0 {
                return DayAssessment(date: day, status: .neutral)
            }

            if completedCount == totalCount {
                return DayAssessment(date: day, status: .completed)
            }

            return DayAssessment(date: day, status: .incomplete)
        }
    }

    private func currentStreak(
        dayAssessments: [DayAssessment],
        upTo date: Date,
        calendar: Calendar,
        rules: DailyStreakRules
    ) -> Int {
        let assessmentsByDate = Dictionary(uniqueKeysWithValues: dayAssessments.map { ($0.date, $0.status) })
        let relevantDays = dayAssessments.map(\.date)

        guard let anchorDate = anchorDate(
            assessmentsByDate: assessmentsByDate,
            relevantDays: relevantDays,
            upTo: date,
            calendar: calendar
        ) else {
            return 0
        }

        return streakEnding(
            at: anchorDate,
            assessmentsByDate: assessmentsByDate,
            earliestRelevantDay: relevantDays.first,
            calendar: calendar,
            rules: rules
        )
    }

    private func longestStreak(
        dayAssessments: [DayAssessment],
        rules: DailyStreakRules
    ) -> (longest: Int, lastCompletedDate: Date?) {
        var longest = 0
        var currentRun = 0
        var lastCompletedDate: Date?

        for assessment in dayAssessments.sorted(by: { $0.date < $1.date }) {
            switch assessment.status {
            case .neutral:
                continue
            case .completed:
                currentRun += 1
                longest = max(longest, currentRun)
                lastCompletedDate = assessment.date
            case .incomplete:
                if rules.graceDays == 0 {
                    currentRun = 0
                } else {
                    currentRun = max(currentRun - 1, 0)
                }
            }
        }

        return (longest, lastCompletedDate)
    }

    private func anchorDate(
        assessmentsByDate: [Date: DayAssessment.Status],
        relevantDays: [Date],
        upTo date: Date,
        calendar: Calendar
    ) -> Date? {
        let targetDay = calendar.startOfDay(for: date)
        let latestRelevantDay = relevantDays.last(where: { $0 <= targetDay })

        guard let latestRelevantDay else {
            return nil
        }

        switch assessmentsByDate[latestRelevantDay] {
        case .completed?:
            return latestRelevantDay
        case .incomplete?:
            return relevantDays.last(where: { $0 < latestRelevantDay && assessmentsByDate[$0] == .completed })
        case .neutral?, nil:
            return relevantDays.last(where: { $0 <= targetDay && assessmentsByDate[$0] == .completed })
        }
    }

    private func streakEnding(
        at anchorDate: Date,
        assessmentsByDate: [Date: DayAssessment.Status],
        earliestRelevantDay: Date?,
        calendar: Calendar,
        rules: DailyStreakRules
    ) -> Int {
        var streak = 0
        var cursor = anchorDate

        while true {
            guard let status = assessmentsByDate[cursor] else {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                    break
                }

                if let earliestRelevantDay, previousDay < earliestRelevantDay {
                    break
                }

                cursor = previousDay
                continue
            }

            switch status {
            case .neutral:
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                    return streak
                }
                if let earliestRelevantDay, previousDay < earliestRelevantDay {
                    return streak
                }
                cursor = previousDay
            case .completed:
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                    return streak
                }
                if let earliestRelevantDay, previousDay < earliestRelevantDay {
                    return streak
                }
                cursor = previousDay
            case .incomplete:
                if rules.graceDays > 0 {
                    streak = max(streak - 1, 0)
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                        return streak
                    }
                    if let earliestRelevantDay, previousDay < earliestRelevantDay {
                        return streak
                    }
                    cursor = previousDay
                } else {
                    return streak
                }
            }
        }

        return streak
    }

    private func completionKey(habitID: UUID, date: Date) -> String {
        "\(habitID.uuidString)-\(date.timeIntervalSinceReferenceDate)"
    }
}

struct TodayDeckOrderingEngine {
    private let rhythmConfiguration: DailyRhythmConfiguration
    private let resurfacingThreshold = 40

    init(rhythmConfiguration: DailyRhythmConfiguration = .default) {
        self.rhythmConfiguration = rhythmConfiguration
    }

    func orderedStates(
        _ states: [DailyHabitState],
        habits: [Habit],
        daySectionsByID: [UUID: HabitDaySection] = [:],
        on date: Date,
        calendar: Calendar = .current
    ) -> [DailyHabitState] {
        let habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let activeHabitCount = states.filter { $0.status == .pending || $0.status == .deferred }.count

        return states.sorted {
            let lhs = displayPriority(
                for: $0,
                habit: habitsByID[$0.habitID],
                daySectionsByID: daySectionsByID,
                activeHabitCount: activeHabitCount,
                on: date,
                calendar: calendar
            )
            let rhs = displayPriority(
                for: $1,
                habit: habitsByID[$1.habitID],
                daySectionsByID: daySectionsByID,
                activeHabitCount: activeHabitCount,
                on: date,
                calendar: calendar
            )

            if lhs != rhs {
                return lhs > rhs
            }

            return $0.habitID.uuidString < $1.habitID.uuidString
        }
    }

    func shouldResurfaceDeferredState(
        _ state: DailyHabitState,
        habit: Habit?,
        daySectionsByID: [UUID: HabitDaySection] = [:],
        activeHabitCount: Int,
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard state.status == .deferred, let habit else {
            return false
        }

        return resurfacingScore(
            for: state,
            habit: habit,
            daySectionsByID: daySectionsByID,
            activeHabitCount: activeHabitCount,
            on: date,
            calendar: calendar
        ) >= resurfacingThreshold
    }

    /// Transparent ordering formula for the Today deck.
    ///
    /// Higher scores appear sooner. The score is intentionally additive so we can
    /// explain and test it without a hidden model:
    /// - deckPriority: editorial or manual nudges
    /// - explicit timing: exact times and windows outrank broad rhythm hints
    /// - rhythm fit: Morning / Day / Evening / Anytime relevance
    /// - recency: recently deferred cards wait longer
    /// - current pass: later passes get a small return boost
    /// - remaining active habits: the deck becomes more willing to resurface cards as the queue thins out
    /// - end-of-day bonus: cards become a little more eager as the day winds down
    /// - deferCount penalty: repeated deferrals still push a card back
    ///
    /// Deferred cards only resurface when both this score and the nextEligibleAt gate say yes.
    private func displayPriority(
        for state: DailyHabitState,
        habit: Habit?,
        daySectionsByID: [UUID: HabitDaySection],
        activeHabitCount: Int,
        on date: Date,
        calendar: Calendar
    ) -> Int {
        guard let habit else {
            return Int.min / 2
        }

        var score = resurfacingScore(
            for: state,
            habit: habit,
            daySectionsByID: daySectionsByID,
            activeHabitCount: activeHabitCount,
            on: date,
            calendar: calendar
        )

        switch state.status {
        case .pending:
            break
        case .deferred:
            score -= 12
        case .completed:
            score -= 1_000
        case .expired, .skipped:
            score -= 500
        }

        return score
    }

    private func resurfacingScore(
        for state: DailyHabitState,
        habit: Habit,
        daySectionsByID: [UUID: HabitDaySection],
        activeHabitCount: Int,
        on date: Date,
        calendar: Calendar
    ) -> Int {
        var score = state.deckPriority
        score += rhythmConfiguration.priorityScore(for: habit.dailyRhythm, at: date, calendar: calendar)
        score += daySectionScore(for: habit, daySectionsByID: daySectionsByID, on: date, calendar: calendar)
        score += explicitTimingScore(for: habit.timeMode, on: date, calendar: calendar)
        score += advancedTimingScore(for: habit.advancedSchedule, on: date, calendar: calendar)
        score += recencyScore(for: state.lastDeferredAt, now: date, calendar: calendar)
        score += currentPassScore(for: state)
        score += remainingActiveBonus(activeHabitCount: activeHabitCount)
        score += endOfDayBonus(for: date, calendar: calendar)
        score -= state.deferCount * 6

        return score
    }

    private func daySectionScore(
        for habit: Habit,
        daySectionsByID: [UUID: HabitDaySection],
        on date: Date,
        calendar: Calendar
    ) -> Int {
        guard let sectionID = habit.daySectionID, let section = daySectionsByID[sectionID] else {
            return 0
        }

        var score = max(0, 14 - min(max(section.order, 0), 7) * 2)

        if let metadata = section.timeMetadata {
            if metadata.contains(date, calendar: calendar) {
                let progress = DailyRhythmTimeRange(start: metadata.start, end: metadata.end).progress(at: date, calendar: calendar) ?? 0
                score += 14 + Int((progress * 8).rounded())
            } else {
                let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
                let startMinute = metadata.start.minutesSinceStartOfDay()
                let endMinute = metadata.end.minutesSinceStartOfDay()

                if minuteOfDay < startMinute {
                    score += 8
                } else if minuteOfDay > endMinute {
                    score += 2
                }
            }
        } else if let period = section.period {
            switch period {
            case .morning:
                score += rhythmConfiguration.priorityScore(for: .morning, at: date, calendar: calendar)
            case .afternoon:
                score += rhythmConfiguration.priorityScore(for: .day, at: date, calendar: calendar)
            case .evening:
                score += rhythmConfiguration.priorityScore(for: .evening, at: date, calendar: calendar)
            }
        } else {
            score += section.isActive ? 4 : -4
        }

        return score
    }

    private func recencyScore(for lastDeferredAt: Date?, now: Date, calendar: Calendar) -> Int {
        guard let lastDeferredAt else {
            return 0
        }

        let minutes = max(calendar.dateComponents([.minute], from: lastDeferredAt, to: now).minute ?? 0, 0)
        return min(minutes / 5, 6) * 2
    }

    private func currentPassScore(for state: DailyHabitState) -> Int {
        min(max(state.currentPass - 1, 0), 4) * 3
    }

    private func remainingActiveBonus(activeHabitCount: Int) -> Int {
        let scarcity = max(0, 8 - min(activeHabitCount, 8))
        return scarcity * 2
    }

    private func endOfDayBonus(for date: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) else {
            return 0
        }

        let minutesRemaining = max(calendar.dateComponents([.minute], from: date, to: endOfDay).minute ?? 0, 0)

        if minutesRemaining <= 60 {
            return 12
        }

        if minutesRemaining <= 180 {
            return 8
        }

        if minutesRemaining <= 360 {
            return 4
        }

        return 0
    }

    private func explicitTimingScore(for timeMode: HabitTimeMode, on date: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: date)

        switch timeMode {
        case .allDay:
            return 8
        case .specificTime(let time):
            let scheduled = calendar.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: 0,
                of: today
            ) ?? today

            let deltaMinutes = abs(calendar.dateComponents([.minute], from: date, to: scheduled).minute ?? 0)
            return max(18, 72 - min(deltaMinutes, 90) * 2)
        case .timeWindow(let window):
            let start = calendar.date(
                bySettingHour: window.start.hour,
                minute: window.start.minute,
                second: 0,
                of: today
            ) ?? today
            let end = calendar.date(
                bySettingHour: window.end.hour,
                minute: window.end.minute,
                second: 0,
                of: today
            ) ?? today

            if window.contains(date, calendar: calendar) {
                let durationMinutes = max(calendar.dateComponents([.minute], from: start, to: end).minute ?? 1, 1)
                let elapsedMinutes = max(calendar.dateComponents([.minute], from: start, to: date).minute ?? 0, 0)
                let progress = min(max(Double(elapsedMinutes) / Double(durationMinutes), 0), 1)
                return 52 + Int((progress * 12).rounded())
            }

            if date < start {
                return 34
            }

            return 6
        }
    }

    private func advancedTimingScore(
        for advancedSchedule: HabitAdvancedSchedule?,
        on date: Date,
        calendar: Calendar
    ) -> Int {
        guard let advancedSchedule else {
            return 0
        }

        let timingWindow = advancedSchedule.timingWindow(on: date, calendar: calendar, rhythmConfiguration: rhythmConfiguration)
        guard let timingWindow else {
            return advancedSchedule.rules.contains(where: { $0.isTimingRule }) ? 6 : 0
        }

        let today = calendar.startOfDay(for: date)
        let start = calendar.date(
            bySettingHour: timingWindow.start.hour,
            minute: timingWindow.start.minute,
            second: 0,
            of: today
        ) ?? today
        let end = calendar.date(
            bySettingHour: timingWindow.end.hour,
            minute: timingWindow.end.minute,
            second: 0,
            of: today
        ) ?? today

        if timingWindow.contains(date, calendar: calendar) {
            let durationMinutes = max(calendar.dateComponents([.minute], from: start, to: end).minute ?? 1, 1)
            let elapsedMinutes = max(calendar.dateComponents([.minute], from: start, to: date).minute ?? 0, 0)
            let progress = min(max(Double(elapsedMinutes) / Double(durationMinutes), 0), 1)
            return 12 + Int((progress * 10).rounded())
        }

        if date < start {
            return 4
        }

        if date > end {
            return 1
        }

        return 0
    }
}
