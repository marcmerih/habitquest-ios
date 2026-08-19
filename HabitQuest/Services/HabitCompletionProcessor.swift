import Foundation

struct CompletionProcessingResult: Sendable {
    let event: CompletionEvent
    let updatedState: DailyHabitState
    let didCreateEvent: Bool
    let newAchievements: [HabitAchievement]
}

struct HabitCompletionProcessor {
    let completionEventStore: any CompletionEventStoring
    let dailyHabitStateStore: any DailyHabitStateStoring
    let progressionStore: any HabitProgressionStoring
    let achievementService: HabitAchievementService
    let dailyHabitInstanceEngine: DailyHabitInstanceEngine
    let progressionCalculator: HabitProgressionCalculator

    func processCompletion(
        for habit: Habit,
        state: DailyHabitState,
        source: CompletionSource,
        at timestamp: Date,
        calendar: Calendar = .current
    ) throws -> CompletionProcessingResult {
        let logicalCompletionDate = calendar.startOfDay(for: state.date)

        if let existingEvent = try completionEventStore.completionEvent(for: habit.id, on: logicalCompletionDate, calendar: calendar) {
            let updatedState = dailyHabitInstanceEngine.complete(state, at: existingEvent.timestamp)
            try dailyHabitStateStore.upsertState(updatedState, calendar: calendar)
            let newAchievements = try achievementService.reconcileAchievements(calendar: calendar).newAchievements
            return CompletionProcessingResult(
                event: existingEvent,
                updatedState: updatedState,
                didCreateEvent: false,
                newAchievements: newAchievements
            )
        }

        let event = CompletionEvent(
            habitID: habit.id,
            timestamp: timestamp,
            logicalCompletionDate: logicalCompletionDate,
            source: source
        )

        let storedEvent = try completionEventStore.upsertCompletion(event, calendar: calendar)
        let updatedState = dailyHabitInstanceEngine.complete(state, at: timestamp)
        try dailyHabitStateStore.upsertState(updatedState, calendar: calendar)
        let currentProgression = try progressionStore.loadProgression()
        let updatedProgression = progressionCalculator.state(
            after: progressionCalculator.award(for: habit),
            to: currentProgression,
            at: timestamp
        )
        try progressionStore.saveProgression(updatedProgression)
        let newAchievements = try achievementService.reconcileAchievements(calendar: calendar).newAchievements

        return CompletionProcessingResult(
            event: storedEvent,
            updatedState: updatedState,
            didCreateEvent: true,
            newAchievements: newAchievements
        )
    }
}
