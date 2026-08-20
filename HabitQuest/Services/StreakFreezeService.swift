import Foundation

extension Notification.Name {
    static let habitQuestStreakFreezeDidChange = Notification.Name("habitquest.streakFreeze.didChange")
}

enum StreakFreezePurchaseResult: Sendable, Equatable {
    case saved
    case insufficientXP(required: Int, available: Int)
    case noPendingOpportunity
}

final class StreakFreezeService: ObservableObject {
    @Published private(set) var state: StreakFreezeState = .default

    private let store: any StreakFreezeStoring
    private let habitRepository: any HabitRepository
    private let dailyHabitStateStore: any DailyHabitStateStoring
    private let completionEventStore: any CompletionEventStoring
    private let progressionStore: any HabitProgressionStoring
    private let dateService: any DateProviding
    private let dailyStreakCalculator: DailyStreakCalculator
    private let costCalculator = StreakFreezeCostCalculator()

    init(
        store: any StreakFreezeStoring,
        habitRepository: any HabitRepository,
        dailyHabitStateStore: any DailyHabitStateStoring,
        completionEventStore: any CompletionEventStoring,
        progressionStore: any HabitProgressionStoring,
        dateService: any DateProviding,
        dailyStreakCalculator: DailyStreakCalculator = DailyStreakCalculator()
    ) {
        self.store = store
        self.habitRepository = habitRepository
        self.dailyHabitStateStore = dailyHabitStateStore
        self.completionEventStore = completionEventStore
        self.progressionStore = progressionStore
        self.dateService = dateService
        self.dailyStreakCalculator = dailyStreakCalculator
    }

    var activeOpportunity: StreakFreezeOpportunity? {
        state.pendingOpportunity
    }

    var hasLostStreakNotice: Bool {
        state.pendingOpportunity == nil && state.lastLostDay != nil
    }

    func loadState() {
        state = (try? store.loadState()) ?? .default
    }

    func syncState() {
        do {
            let now = dateService.now
            let calendar = dateService.calendar
            let habits = try habitRepository.fetchHabits()
            let dailyStates = try dailyHabitStateStore.loadStates()
            let completionEvents = try completionEventStore.loadEvents()

            let currentSummary = dailyStreakCalculator.summary(
                for: habits,
                states: dailyStates,
                completionEvents: completionEvents,
                upTo: now,
                calendar: calendar
            )

            let previousDayEnd = previousDayEnd(before: now, calendar: calendar)
            let previousSummary = dailyStreakCalculator.summary(
                for: habits,
                states: dailyStates,
                completionEvents: completionEvents,
                upTo: previousDayEnd,
                calendar: calendar
            )

            var updatedState = (try? store.loadState()) ?? .default

            if currentSummary.currentDailyStreak > 0 {
                updatedState.pendingOpportunity = nil
                updatedState.lastLostDay = nil
            } else if let pending = updatedState.pendingOpportunity {
                if now > pending.deadline {
                    updatedState.lastLostDay = pending.brokenDay
                    updatedState.pendingOpportunity = nil
                }
            } else if previousSummary.currentDailyStreak > 0 {
                let brokenDay = calendar.startOfDay(for: previousDayEnd)
                let deadline = calendar.date(byAdding: .day, value: 1, to: endOfDay(for: brokenDay, calendar: calendar)) ?? pendingDeadlineFallback(for: now)
                updatedState.pendingOpportunity = StreakFreezeOpportunity(
                    brokenDay: brokenDay,
                    detectedAt: now,
                    deadline: deadline,
                    baselineStreak: previousSummary.currentDailyStreak,
                    costXP: costCalculator.cost(for: habits)
                )
                updatedState.lastLostDay = nil
            }

            if updatedState != state {
                try store.saveState(updatedState)
                state = updatedState
                NotificationCenter.default.post(name: .habitQuestStreakFreezeDidChange, object: nil)
            }
        } catch {
            // Streak freeze is a graceful enhancement; if syncing fails we keep the UI functional.
        }
    }

    func purchaseFreeze(usingXP now: Date? = nil) -> StreakFreezePurchaseResult {
        guard let opportunity = state.pendingOpportunity else {
            return .noPendingOpportunity
        }

        do {
            let progression = try progressionStore.loadProgression()
            guard progression.lifetimeXP >= opportunity.costXP else {
                return .insufficientXP(required: opportunity.costXP, available: progression.lifetimeXP)
            }

            let timestamp = now ?? dateService.now
            var updatedProgression = progression
            updatedProgression.lifetimeXP = max(0, progression.lifetimeXP - opportunity.costXP)
            updatedProgression.lastUpdatedAt = timestamp
            try progressionStore.saveProgression(updatedProgression)

            var dailyStates = try dailyHabitStateStore.loadStates()
            let brokenDay = dateService.calendar.startOfDay(for: opportunity.brokenDay)
            for index in dailyStates.indices where dateService.calendar.isDate(dailyStates[index].date, inSameDayAs: brokenDay) {
                dailyStates[index].streakFreezeAppliedAt = timestamp
            }
            try dailyHabitStateStore.saveStates(dailyStates)

            var updatedState = state
            updatedState.pendingOpportunity = nil
            updatedState.lastLostDay = nil
            try store.saveState(updatedState)
            state = updatedState

            NotificationCenter.default.post(name: .habitQuestStreakFreezeDidChange, object: nil)
            return .saved
        } catch {
            return .noPendingOpportunity
        }
    }

    func dismissOpportunity() {
        // Dismissal is intentionally session-only. The next app launch can present again until expiry or redemption.
    }

    func noticeMessage() -> String? {
        guard hasLostStreakNotice, let lastLostDay = state.lastLostDay else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dayText = formatter.string(from: lastLostDay)
        return "Your streak ended on \(dayText). You can start a new run whenever you’re ready."
    }

    private func previousDayEnd(before date: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: date)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        return endOfDay(for: yesterday, calendar: calendar)
    }

    private func endOfDay(for date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 23, minute: 59, second: 59, of: calendar.startOfDay(for: date)) ?? date
    }

    private func pendingDeadlineFallback(for date: Date) -> Date {
        date.addingTimeInterval(24 * 60 * 60)
    }
}
