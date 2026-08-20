import Foundation

struct HabitDayResolutionResult: Sendable {
    let resolvedDayCount: Int
    let updatedStates: [DailyHabitState]
}

struct HabitDayResolutionService {
    let habitRepository: any HabitRepository
    let completionEventStore: any CompletionEventStoring
    let dailyHabitStateStore: any DailyHabitStateStoring
    let dailyHabitInstanceEngine: DailyHabitInstanceEngine
    let dailyStreakCalculator: DailyStreakCalculator
    let streakFreezeStore: any StreakFreezeStoring
    let streakFreezeCostCalculator: StreakFreezeCostCalculator

    func resolveElapsedDays(upTo timestamp: Date, calendar: Calendar = .current) throws -> HabitDayResolutionResult {
        let habits = try habitRepository.fetchHabits()
        let completionEvents = try completionEventStore.loadEvents()
        let storedStates = try dailyHabitStateStore.loadStates()
        let currentDay = calendar.startOfDay(for: timestamp)

        guard let latestStoredDay = storedStates.map({ calendar.startOfDay(for: $0.date) }).max(),
              latestStoredDay < currentDay else {
            return HabitDayResolutionResult(resolvedDayCount: 0, updatedStates: storedStates)
        }

        var resolvedStates = storedStates
        var resolvedDayCount = 0
        var cursor = calendar.startOfDay(for: latestStoredDay)

        while cursor < currentDay {
            let endOfDay = endOfDay(for: cursor, calendar: calendar)
            let snapshot = dailyHabitInstanceEngine.generateSnapshot(
                for: habits,
                persistedStates: resolvedStates,
                on: cursor,
                now: endOfDay,
                calendar: calendar
            )

            let historicalStates = snapshot.states.map { state -> DailyHabitState in
                guard let habit = habits.first(where: { $0.id == state.habitID }) else {
                    return state
                }

                if let completionEvent = completionEvents.first(where: {
                    $0.habitID == habit.id && calendar.isDate($0.logicalCompletionDate, inSameDayAs: cursor)
                }) {
                    var completedState = dailyHabitInstanceEngine.complete(state, at: completionEvent.timestamp)
                    completedState.completedAt = completionEvent.timestamp
                    return completedState
                }

                guard state.status == .pending || state.status == .deferred else {
                    return state
                }

                var expiredState = state
                expiredState.status = .expired
                expiredState.completedAt = nil
                expiredState.nextEligibleAt = nil
                return expiredState
            }

            resolvedStates = merge(resolvedStates, with: historicalStates, calendar: calendar)

            if dayShouldReceiveStreakFreeze(
                for: cursor,
                historicalStates: historicalStates,
                resolvedStatesBeforeCurrentDay: resolvedStates,
                habits: habits,
                completionEvents: completionEvents,
                calendar: calendar
            ) {
                let opportunity = makeStreakFreezeOpportunity(
                    for: cursor,
                    habits: habits,
                    states: resolvedStates,
                    completionEvents: completionEvents,
                    calendar: calendar,
                    now: endOfDay
                )

                try? streakFreezeStore.recordOpportunity(opportunity)
            }

            resolvedDayCount += 1

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        try dailyHabitStateStore.saveStates(resolvedStates)
        return HabitDayResolutionResult(resolvedDayCount: resolvedDayCount, updatedStates: resolvedStates)
    }

    private func merge(
        _ existing: [DailyHabitState],
        with resolved: [DailyHabitState],
        calendar: Calendar
    ) -> [DailyHabitState] {
        var merged = existing

        for state in resolved {
            if let index = merged.firstIndex(where: { $0.habitID == state.habitID && calendar.isDate($0.date, inSameDayAs: state.date) }) {
                merged[index] = state
            } else {
                merged.append(state)
            }
        }

        return merged.sorted {
            if $0.date == $1.date {
                return $0.habitID.uuidString < $1.habitID.uuidString
            }
            return $0.date < $1.date
        }
    }

    private func endOfDay(for date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 23, minute: 59, second: 59, of: calendar.startOfDay(for: date)) ?? date
    }

    private func dayShouldReceiveStreakFreeze(
        for day: Date,
        historicalStates: [DailyHabitState],
        resolvedStatesBeforeCurrentDay: [DailyHabitState],
        habits: [Habit],
        completionEvents: [CompletionEvent],
        calendar: Calendar
    ) -> Bool {
        let previousDayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: calendar.date(byAdding: .day, value: -1, to: day) ?? day) ?? day
        let priorSummary = dailyStreakCalculator.summary(
            for: habits,
            states: resolvedStatesBeforeCurrentDay,
            completionEvents: completionEvents,
            upTo: previousDayEnd,
            calendar: calendar
        )

        guard priorSummary.currentDailyStreak > 0 else {
            return false
        }

        return historicalStates.contains { $0.status != .completed && $0.streakFreezeAppliedAt == nil }
    }

    private func makeStreakFreezeOpportunity(
        for day: Date,
        habits: [Habit],
        states: [DailyHabitState],
        completionEvents: [CompletionEvent],
        calendar: Calendar,
        now: Date
    ) -> StreakFreezeOpportunity {
        let previousDayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: calendar.date(byAdding: .day, value: -1, to: day) ?? day) ?? now
        let priorSummary = dailyStreakCalculator.summary(
            for: habits,
            states: states.filter { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: day) },
            completionEvents: completionEvents,
            upTo: previousDayEnd,
            calendar: calendar
        )
        let brokenDay = calendar.startOfDay(for: day)
        let deadline = calendar.date(byAdding: .day, value: 1, to: endOfDay(for: brokenDay, calendar: calendar)) ?? now.addingTimeInterval(24 * 60 * 60)
        let cost = streakFreezeCostCalculator.cost(for: habits)

        return StreakFreezeOpportunity(
            brokenDay: brokenDay,
            detectedAt: now,
            deadline: deadline,
            baselineStreak: priorSummary.currentDailyStreak,
            costXP: cost
        )
    }
}
