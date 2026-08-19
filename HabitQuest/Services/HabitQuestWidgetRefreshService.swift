import Foundation
import WidgetKit

final class HabitQuestWidgetRefreshService {
    private let snapshotStore: HabitQuestWidgetSnapshotStore
    private let dateService: any DateProviding
    private let habitRepository: any HabitRepository
    private let dailyHabitStateStore: any DailyHabitStateStoring
    private let completionEventStore: any CompletionEventStoring
    private let progressionStore: any HabitProgressionStoring
    private let habitDaySectionStore: any HabitDaySectionStoring
    private let dailyStreakCalculator: DailyStreakCalculator
    private let habitProgressCalculator: HabitProgressCalculator
    private let momentumCalculator: HabitMomentumCalculator
    private let premiumEntitlementService: PremiumEntitlementService

    init(
        snapshotStore: HabitQuestWidgetSnapshotStore,
        dateService: any DateProviding,
        habitRepository: any HabitRepository,
        dailyHabitStateStore: any DailyHabitStateStoring,
        completionEventStore: any CompletionEventStoring,
        progressionStore: any HabitProgressionStoring,
        habitDaySectionStore: any HabitDaySectionStoring,
        dailyStreakCalculator: DailyStreakCalculator,
        habitProgressCalculator: HabitProgressCalculator,
        momentumCalculator: HabitMomentumCalculator,
        premiumEntitlementService: PremiumEntitlementService
    ) {
        self.snapshotStore = snapshotStore
        self.dateService = dateService
        self.habitRepository = habitRepository
        self.dailyHabitStateStore = dailyHabitStateStore
        self.completionEventStore = completionEventStore
        self.progressionStore = progressionStore
        self.habitDaySectionStore = habitDaySectionStore
        self.dailyStreakCalculator = dailyStreakCalculator
        self.habitProgressCalculator = habitProgressCalculator
        self.momentumCalculator = momentumCalculator
        self.premiumEntitlementService = premiumEntitlementService
    }

    func refreshSnapshots() {
        let now = dateService.now
        let calendar = dateService.calendar

        do {
            let habits = try habitRepository.fetchHabits()
            let states = try dailyHabitStateStore.loadStates()
            let completionEvents = try completionEventStore.loadEvents()
            let sections = try habitDaySectionStore.loadSections()
            _ = try progressionStore.loadProgression()

            let habitSummaries = habits.map { habit -> HabitQuestWidgetHabitSummary in
                let summary = habitProgressCalculator.summary(
                    for: habit,
                    completionEvents: completionEvents,
                    upTo: now,
                    calendar: calendar
                )

                let sectionName = sections.first(where: { $0.id == habit.daySectionID })?.displayTitle

                return HabitQuestWidgetHabitSummary(
                    id: habit.id,
                    title: habit.title,
                    icon: habit.icon,
                    category: habit.category,
                    accentHex: habit.colorHex,
                    dailyRhythmRaw: habit.dailyRhythm.rawValue,
                    currentStreak: summary.currentStreak,
                    completionRate: summary.lifetimeConsistencyPercentage,
                    isPaused: habit.isPaused,
                    isArchived: habit.isArchived,
                    sectionID: habit.daySectionID,
                    sectionName: sectionName
                )
            }

            let activeSections = sections
                .filter(\.isActive)
                .sorted { $0.order < $1.order }
                .map { section in
                    HabitQuestWidgetDaySectionSummary(
                        id: section.id,
                        name: section.displayTitle,
                        icon: section.icon,
                        order: section.order,
                        isActive: section.isActive,
                        periodRaw: section.period?.rawValue,
                        subtitle: section.contextualNotes
                    )
                }

            let todayStates = states.filter { calendar.isDate($0.date, inSameDayAs: now) }
            let todayCompleted = todayStates.filter { $0.status == .completed }.count
            let todayRemaining = todayStates.filter { $0.status == .pending || $0.status == .deferred }.count

            let dailySummary = dailyStreakCalculator.summary(
                for: habits,
                states: states,
                completionEvents: completionEvents,
                upTo: now,
                calendar: calendar
            )
            let momentumSummary = momentumCalculator.summary(
                for: habits,
                completionEvents: completionEvents,
                upTo: now,
                calendar: calendar
            )
            let snapshot = HabitQuestWidgetSnapshot(
                generatedAt: now,
                accessTierRaw: widgetAccessTier(from: premiumEntitlementService.accessState).rawValue,
                habits: habitSummaries,
                sections: activeSections,
                metrics: HabitQuestWidgetMetricsSummary(
                    todayCompleted: todayCompleted,
                    todayRemaining: todayRemaining,
                    currentDailyStreak: dailySummary.currentDailyStreak,
                    longestDailyStreak: dailySummary.longestDailyStreak,
                    currentMomentum: momentumSummary.currentMomentum,
                    completionRate: completionRate(from: habits, completionEvents: completionEvents, calendar: calendar)
                )
            )

            snapshotStore.saveSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            snapshotStore.saveSnapshot(
                HabitQuestWidgetSnapshot(
                    generatedAt: now,
                    accessTierRaw: widgetAccessTier(from: premiumEntitlementService.accessState).rawValue,
                    habits: [],
                    sections: [],
                    metrics: HabitQuestWidgetMetricsSummary(
                        todayCompleted: 0,
                        todayRemaining: 0,
                        currentDailyStreak: 0,
                        longestDailyStreak: 0,
                        currentMomentum: 0,
                        completionRate: nil
                    )
                )
            )
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func widgetAccessTier(from state: PremiumAccessState) -> HabitQuestWidgetAccessTier {
        switch state.tier {
        case .free:
            return .free
        case .trial:
            return .trial
        case .premium:
            return .premium
        }
    }

    private func completionRate(
        from habits: [Habit],
        completionEvents: [CompletionEvent],
        calendar: Calendar
    ) -> Double? {
        let activeHabits = habits.filter { !$0.isArchived }
        guard !activeHabits.isEmpty else {
            return nil
        }

        let summaries = activeHabits.map {
            habitProgressCalculator.summary(
                for: $0,
                completionEvents: completionEvents,
                upTo: dateService.now,
                calendar: calendar
            )
        }

        let totals = summaries.compactMap(\.lifetimeConsistencyPercentage)
        guard !totals.isEmpty else {
            return nil
        }

        return totals.reduce(0, +) / Double(totals.count)
    }
}
