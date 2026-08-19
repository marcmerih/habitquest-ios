import Foundation

struct HabitAchievementReconciliationResult: Sendable {
    let newAchievements: [HabitAchievement]
    let allAchievements: [HabitAchievement]
}

struct HabitAchievementService {
    let achievementStore: any HabitAchievementStoring
    let habitRepository: any HabitRepository
    let completionEventStore: any CompletionEventStoring
    let dailyHabitStateStore: any DailyHabitStateStoring
    let progressionStore: any HabitProgressionStoring
    let dateService: any DateProviding
    let evaluator: HabitMilestoneEvaluator

    func loadAchievements() throws -> [HabitAchievement] {
        try achievementStore.loadAchievements()
    }

    func reconcileAchievements(calendar: Calendar? = nil) throws -> HabitAchievementReconciliationResult {
        let calendar = calendar ?? dateService.calendar
        let now = dateService.now

        let habits = try habitRepository.fetchHabits()
        let completionEvents = try completionEventStore.loadEvents()
        let dailyStates = try dailyHabitStateStore.loadStates()
        let progression = try progressionStore.loadProgression()
        let existingAchievements = try achievementStore.loadAchievements()
        let existingIDs = Set(existingAchievements.map(\.id))

        let newAchievements = evaluator.evaluate(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            progression: progression,
            earnedAchievementIDs: existingIDs,
            at: now,
            calendar: calendar
        )

        guard !newAchievements.isEmpty else {
            return HabitAchievementReconciliationResult(
                newAchievements: [],
                allAchievements: existingAchievements
            )
        }

        let allAchievements = try achievementStore.appendAchievements(newAchievements)
        return HabitAchievementReconciliationResult(
            newAchievements: newAchievements,
            allAchievements: allAchievements
        )
    }
}
