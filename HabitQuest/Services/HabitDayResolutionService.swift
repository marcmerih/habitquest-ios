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
}
