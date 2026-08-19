import SwiftUI

struct HabitQuestEnvironment: @unchecked Sendable {
    let dateService: any DateProviding
    let hapticService: any HapticServicing
    let notificationScheduler: any NotificationScheduling
    let premiumPromotionalNotificationService: any PremiumPromotionalNotificationScheduling
    let notificationPreferencesStore: any NotificationPreferencesStoring
    let analyticsTracker: any AnalyticsTracking
    let premiumEntitlementService: PremiumEntitlementService
    let premiumPromotionManager: PremiumPromotionManager
    let premiumPromotionRouter: PremiumPromotionRouter
    let personalizationStore: HabitQuestPersonalizationStore
    let widgetSnapshotStore: HabitQuestWidgetSnapshotStore
    let widgetRefreshService: HabitQuestWidgetRefreshService
    let subscriptionManager: SubscriptionManager
    let habitRepository: any HabitRepository
    let habitDaySectionStore: any HabitDaySectionStoring
    let dailyHabitStateStore: any DailyHabitStateStoring
    let completionEventStore: any CompletionEventStoring
    let progressionStore: any HabitProgressionStoring
    let achievementStore: any HabitAchievementStoring
    let dayResolutionService: HabitDayResolutionService
    let localDataManagementService: HabitQuestLocalDataManagementService
    let schedulingEngine: HabitSchedulingEngine
    let rhythmConfiguration: DailyRhythmConfiguration
    let dailyHabitInstanceEngine: DailyHabitInstanceEngine
    let completionProcessor: HabitCompletionProcessor
    let achievementService: HabitAchievementService
    let dailyStreakCalculator: DailyStreakCalculator
    let streakCalculator: HabitStreakCalculator
    let habitProgressCalculator: HabitProgressCalculator
    let habitProgressionCalculator: HabitProgressionCalculator
    let momentumCalculator: HabitMomentumCalculator
    let habitAnalyticsCalculator: HabitAnalyticsCalculator
    let premiumAnalyticsCalculator: HabitPremiumAnalyticsCalculator
    let deckOrderingEngine: TodayDeckOrderingEngine

    static let live: HabitQuestEnvironment = {
        let rhythmConfiguration: DailyRhythmConfiguration = .default
        let dailyHabitStateStore = LocalDailyHabitStateStore.live()
        let completionEventStore = LocalCompletionEventStore.live()
        let progressionStore = LocalHabitProgressionStore.live()
        let achievementStore = LocalHabitAchievementStore.live()
        let habitDaySectionStore = LocalHabitDaySectionStore.live()
        let notificationPreferencesStore = LocalNotificationPreferencesStore.live()
        let dateService = SystemDateService()
        let habitRepository = LocalHabitRepository.live()
        let personalizationStore = HabitQuestPersonalizationStore.shared
        let widgetSnapshotStore = HabitQuestWidgetSnapshotStore.shared
        let premiumPromotionRouter = PremiumPromotionRouter.shared
        let premiumPromotionManager = PremiumPromotionManager(clock: dateService)
#if DEBUG
        let analyticsTracker: any AnalyticsTracking = DebugAnalyticsTracker()
#else
        let analyticsTracker: any AnalyticsTracking = NoOpAnalyticsTracker()
#endif
        let premiumEntitlementService = PremiumEntitlementService(
            accessState: .free,
            personalizationStore: personalizationStore,
            widgetSnapshotStore: widgetSnapshotStore
        )
        let widgetRefreshService = HabitQuestWidgetRefreshService(
            snapshotStore: widgetSnapshotStore,
            dateService: dateService,
            habitRepository: habitRepository,
            dailyHabitStateStore: dailyHabitStateStore,
            completionEventStore: completionEventStore,
            progressionStore: progressionStore,
            habitDaySectionStore: habitDaySectionStore,
            dailyStreakCalculator: DailyStreakCalculator(),
            habitProgressCalculator: HabitProgressCalculator(),
            momentumCalculator: HabitMomentumCalculator(),
            premiumEntitlementService: premiumEntitlementService
        )
        let subscriptionManager = SubscriptionManager(
            client: LiveStoreKitSubscriptionClient(),
            entitlementService: premiumEntitlementService,
            analyticsTracker: analyticsTracker
        )
        let dailyHabitInstanceEngine = DailyHabitInstanceEngine(rhythmConfiguration: rhythmConfiguration)
        let dayResolutionService = HabitDayResolutionService(
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: dailyHabitStateStore,
            dailyHabitInstanceEngine: dailyHabitInstanceEngine
        )
        let localDataManagementService = HabitQuestLocalDataManagementService(
            habitRepository: habitRepository,
            habitDaySectionStore: habitDaySectionStore,
            dailyHabitStateStore: dailyHabitStateStore,
            completionEventStore: completionEventStore,
            progressionStore: progressionStore,
            achievementStore: achievementStore,
            notificationPreferencesStore: notificationPreferencesStore,
            dateService: dateService,
            dailyStreakCalculator: DailyStreakCalculator(),
            habitProgressCalculator: HabitProgressCalculator(),
            momentumCalculator: HabitMomentumCalculator()
        )
        let achievementService = HabitAchievementService(
            achievementStore: achievementStore,
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: dailyHabitStateStore,
            progressionStore: progressionStore,
            dateService: dateService,
            evaluator: HabitMilestoneEvaluator()
        )

        return HabitQuestEnvironment(
            dateService: dateService,
            hapticService: SystemHapticService(),
            notificationScheduler: HabitReminderNotificationService(
                preferencesStore: notificationPreferencesStore,
                daySectionStore: habitDaySectionStore,
                premiumEntitlementProvider: premiumEntitlementService
            ),
            premiumPromotionalNotificationService: PremiumPromotionalNotificationService(
                preferencesStore: notificationPreferencesStore,
                premiumEntitlementService: premiumEntitlementService,
                premiumPromotionManager: premiumPromotionManager
            ),
            notificationPreferencesStore: notificationPreferencesStore,
            analyticsTracker: analyticsTracker,
            premiumEntitlementService: premiumEntitlementService,
            premiumPromotionManager: premiumPromotionManager,
            premiumPromotionRouter: premiumPromotionRouter,
            personalizationStore: personalizationStore,
            widgetSnapshotStore: widgetSnapshotStore,
            widgetRefreshService: widgetRefreshService,
            subscriptionManager: subscriptionManager,
            habitRepository: habitRepository,
            habitDaySectionStore: habitDaySectionStore,
            dailyHabitStateStore: dailyHabitStateStore,
            completionEventStore: completionEventStore,
            progressionStore: progressionStore,
            achievementStore: achievementStore,
            dayResolutionService: dayResolutionService,
            localDataManagementService: localDataManagementService,
            schedulingEngine: HabitSchedulingEngine(),
            rhythmConfiguration: rhythmConfiguration,
            dailyHabitInstanceEngine: dailyHabitInstanceEngine,
            completionProcessor: HabitCompletionProcessor(
                completionEventStore: completionEventStore,
                dailyHabitStateStore: dailyHabitStateStore,
                progressionStore: progressionStore,
                achievementService: achievementService,
                dailyHabitInstanceEngine: dailyHabitInstanceEngine,
                progressionCalculator: HabitProgressionCalculator()
            ),
            achievementService: achievementService,
            dailyStreakCalculator: DailyStreakCalculator(),
            streakCalculator: HabitStreakCalculator(),
            habitProgressCalculator: HabitProgressCalculator(),
            habitProgressionCalculator: HabitProgressionCalculator(),
            momentumCalculator: HabitMomentumCalculator(),
            habitAnalyticsCalculator: HabitAnalyticsCalculator(),
            premiumAnalyticsCalculator: HabitPremiumAnalyticsCalculator(),
            deckOrderingEngine: TodayDeckOrderingEngine(rhythmConfiguration: rhythmConfiguration)
        )
    }()
}

private struct HabitQuestEnvironmentKey: EnvironmentKey {
    static let defaultValue = HabitQuestEnvironment.live
}

extension EnvironmentValues {
    var habitQuestEnvironment: HabitQuestEnvironment {
        get { self[HabitQuestEnvironmentKey.self] }
        set { self[HabitQuestEnvironmentKey.self] = newValue }
    }
}
