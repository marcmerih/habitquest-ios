import Foundation

struct StreakFreezeOpportunity: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let brokenDay: Date
    let detectedAt: Date
    let deadline: Date
    let baselineStreak: Int
    let costXP: Int

    init(
        id: UUID = UUID(),
        brokenDay: Date,
        detectedAt: Date,
        deadline: Date,
        baselineStreak: Int,
        costXP: Int
    ) {
        self.id = id
        self.brokenDay = brokenDay
        self.detectedAt = detectedAt
        self.deadline = deadline
        self.baselineStreak = max(baselineStreak, 0)
        self.costXP = max(costXP, 0)
    }
}

struct StreakFreezeState: Codable, Equatable, Sendable {
    var pendingOpportunity: StreakFreezeOpportunity?
    var lastLostDay: Date?

    static let `default` = StreakFreezeState(pendingOpportunity: nil, lastLostDay: nil)
}

struct StreakFreezeCostCalculator {
    /// The freeze cost should stay understandable and should scale with how much advantage a user could gain
    /// from farming XP through harder active habits.
    func cost(for habits: [Habit]) -> Int {
        let activeHabits = habits.filter { !$0.isArchived && !$0.isPaused }
        let activeCount = activeHabits.count
        let difficultCount = activeHabits.filter { ($0.difficulty ?? 0) >= 4 }.count
        let weightedDifficulty = activeHabits.reduce(0) { partialResult, habit in
            partialResult + min(max(habit.difficulty ?? 0, 0), 5)
        }

        let baseCost = 48
        let activeHabitComponent = activeCount * 6
        let difficultHabitComponent = difficultCount * 18
        let weightedDifficultyComponent = weightedDifficulty * 4

        return min(max(baseCost + activeHabitComponent + difficultHabitComponent + weightedDifficultyComponent, 48), 240)
    }
}
