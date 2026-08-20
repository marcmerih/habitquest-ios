import Foundation
import UIKit
import SwiftUI

struct AnalyticsContextMetadata: Codable, Equatable, Hashable, Sendable {
    var source: String?
    var featureIdentifier: String?

    init(source: String? = nil, featureIdentifier: String? = nil) {
        self.source = source
        self.featureIdentifier = featureIdentifier
    }
}

protocol DateProviding {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemDateService: DateProviding {
    var now: Date { Date() }
    var calendar: Calendar { .current }
}

protocol HapticServicing {
    var isEnabled: Bool { get }
    @MainActor
    func play(_ event: HabitQuestHapticEvent)
}

struct NoOpHapticService: HapticServicing {
    let isEnabled = false

    @MainActor
    func play(_ event: HabitQuestHapticEvent) {}
}

struct SystemHapticService: HapticServicing {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    @MainActor
    func play(_ event: HabitQuestHapticEvent) {
        guard isEnabled else { return }

        switch event {
        case .swipeThresholdCrossed:
            UISelectionFeedbackGenerator().selectionChanged()
        case .habitCompleted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .habitDeferred:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .habitCreated:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .milestoneReached:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .fullDayCompleted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

enum HabitQuestHapticEvent: String, Sendable {
    case swipeThresholdCrossed
    case habitCompleted
    case habitDeferred
    case habitCreated
    case milestoneReached
    case fullDayCompleted

    var semanticDescription: String {
        switch self {
        case .swipeThresholdCrossed:
            return "swipe threshold crossed"
        case .habitCompleted:
            return "habit completed"
        case .habitDeferred:
            return "habit deferred"
        case .habitCreated:
            return "habit created"
        case .milestoneReached:
            return "milestone reached"
        case .fullDayCompleted:
            return "full day completed"
        }
    }
}

enum AnalyticsEvent: Sendable, Equatable {
    case appLaunched
    case screenViewed(String)
    case habitCompleted(UUID)
    case premiumPaywallViewed(AnalyticsContextMetadata)
    case premiumFeatureGateViewed(AnalyticsContextMetadata)
    case premiumTrialOffered(AnalyticsContextMetadata)
    case premiumTrialDeclined(AnalyticsContextMetadata)
    case premiumTrialStarted(AnalyticsContextMetadata)
    case premiumPurchaseStarted(AnalyticsContextMetadata)
    case premiumPurchaseCompleted(AnalyticsContextMetadata)
    case premiumPurchaseCancelled(AnalyticsContextMetadata)
    case premiumRestoreStarted(AnalyticsContextMetadata)
    case premiumRestoreCompleted(AnalyticsContextMetadata)
    case premiumManageSubscriptionOpened(AnalyticsContextMetadata)

    var analyticsDescription: String {
        switch self {
        case .appLaunched:
            return "app_launched"
        case .screenViewed(let screen):
            return "screen_viewed screen=\(screen.analyticsSourceIdentifier)"
        case .habitCompleted(let habitID):
            return "habit_completed habit_id=\(habitID.uuidString)"
        case .premiumPaywallViewed(let metadata):
            return "premium_paywall_viewed \(metadata.analyticsDescription)"
        case .premiumFeatureGateViewed(let metadata):
            return "premium_feature_gate_viewed \(metadata.analyticsDescription)"
        case .premiumTrialOffered(let metadata):
            return "premium_trial_offered \(metadata.analyticsDescription)"
        case .premiumTrialDeclined(let metadata):
            return "premium_trial_declined \(metadata.analyticsDescription)"
        case .premiumTrialStarted(let metadata):
            return "premium_trial_started \(metadata.analyticsDescription)"
        case .premiumPurchaseStarted(let metadata):
            return "premium_purchase_started \(metadata.analyticsDescription)"
        case .premiumPurchaseCompleted(let metadata):
            return "premium_purchase_completed \(metadata.analyticsDescription)"
        case .premiumPurchaseCancelled(let metadata):
            return "premium_purchase_cancelled \(metadata.analyticsDescription)"
        case .premiumRestoreStarted(let metadata):
            return "premium_restore_started \(metadata.analyticsDescription)"
        case .premiumRestoreCompleted(let metadata):
            return "premium_restore_completed \(metadata.analyticsDescription)"
        case .premiumManageSubscriptionOpened(let metadata):
            return "premium_manage_subscription_opened \(metadata.analyticsDescription)"
        }
    }
}

private extension AnalyticsContextMetadata {
    var analyticsDescription: String {
        var pieces: [String] = []
        if let source {
            pieces.append("source=\(source.analyticsSourceIdentifier)")
        }
        if let featureIdentifier {
            pieces.append("feature=\(featureIdentifier.analyticsSourceIdentifier)")
        }
        return pieces.joined(separator: " ")
    }
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

struct NoOpAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

struct DebugAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics] \(event.analyticsDescription)")
        #endif
    }
}

extension Notification.Name {
    static let habitQuestStreakFreezeDidChange = Notification.Name("habitquest.streakFreeze.didChange")
}

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

enum StreakFreezeStoreError: LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "HabitQuest could not load your streak freeze state."
        case .saveFailed:
            return "HabitQuest could not save your streak freeze state."
        }
    }
}

protocol StreakFreezeStoring {
    func loadState() throws -> StreakFreezeState
    func saveState(_ state: StreakFreezeState) throws
    func recordOpportunity(_ opportunity: StreakFreezeOpportunity) throws
    func reset() throws
}

extension StreakFreezeStoring {
    func updateState(_ mutate: (inout StreakFreezeState) -> Void) throws -> StreakFreezeState {
        var state = try loadState()
        mutate(&state)
        try saveState(state)
        return state
    }
}

final class LocalStreakFreezeStore: StreakFreezeStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedState: StreakFreezeState

    init(storageURL: URL?, initialState: StreakFreezeState = .default) {
        self.storageURL = storageURL
        self.cachedState = initialState
    }

    static func live() -> LocalStreakFreezeStore {
        LocalStreakFreezeStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalStreakFreezeStore {
        LocalStreakFreezeStore(storageURL: nil)
    }

    func loadState() throws -> StreakFreezeState {
        lock.lock()
        defer { lock.unlock() }

        guard let storageURL else {
            return cachedState
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let state = try HabitPersistenceCodec.decoder.decode(StreakFreezeState.self, from: data)
            cachedState = state
            return state
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                cachedState = .default
                return .default
            }

            throw StreakFreezeStoreError.loadFailed(underlying: error)
        }
    }

    func saveState(_ state: StreakFreezeState) throws {
        lock.lock()
        defer { lock.unlock() }

        cachedState = state

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(state)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw StreakFreezeStoreError.saveFailed(underlying: error)
        }
    }

    func recordOpportunity(_ opportunity: StreakFreezeOpportunity) throws {
        try updateState { state in
            if let existing = state.pendingOpportunity {
                if opportunity.brokenDay > existing.brokenDay {
                    state.pendingOpportunity = opportunity
                }
                return
            }

            state.pendingOpportunity = opportunity
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedState = .default

        guard let storageURL else {
            return
        }

        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }

        let directoryURL = storageURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: directoryURL.path),
            (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path).isEmpty) == true {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    static func defaultStoreURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("HabitQuest", isDirectory: true)
            .appendingPathComponent("StreakFreeze.json", isDirectory: false)
    }
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
                let brokenDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? calendar.startOfDay(for: now)
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

extension String {
    var analyticsSourceIdentifier: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "unknown"
        }

        let scalars = trimmed.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }

            return "_"
        }

        var collapsed = String(scalars)

        while collapsed.contains("__") {
            collapsed = collapsed.replacingOccurrences(of: "__", with: "_")
        }

        collapsed = collapsed
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()

        return collapsed.isEmpty ? "unknown" : collapsed
    }
}
