import Foundation
@preconcurrency import UserNotifications

protocol PremiumPromotionalNotificationScheduling {
    func syncPromotionalNotification(
        for habits: [Habit],
        now: Date,
        calendar: Calendar
    ) async

    func cancelPromotionalNotifications() async
}

struct PremiumPromotionalNotificationPayload: Codable, Equatable, Hashable, Sendable {
    let feature: PremiumFeature
    let origin: PremiumGatePresentationOrigin
    let entryPoint: String

    init(
        feature: PremiumFeature,
        origin: PremiumGatePresentationOrigin = .custom,
        entryPoint: String = "Promotional notification"
    ) {
        self.feature = feature
        self.origin = origin
        self.entryPoint = entryPoint
    }

    var descriptor: PremiumFeatureGateDescriptor {
        feature.gateDescriptor(origin: origin, entryPoint: entryPoint)
    }

    var notificationTitle: String {
        "HabitQuest Premium"
    }

    var notificationBody: String {
        switch feature {
        case .advancedRoutines:
            return "Build a Morning Routine around the habits that matter most."
        case .customDaySections:
            return "Organize your day into calm sections that feel easier to return to."
        case .advancedScheduling:
            return "Shape more flexible schedules without making HabitQuest feel complicated."
        case .multipleReminders:
            return "Want a little more support when a habit needs a second nudge?"
        case .smartReminders:
            return "Let reminders feel a little closer to your real rhythm."
        case .advancedAnalytics:
            return "Want a deeper look at your 90-day progress?"
        case .longTermAnalytics:
            return "See the bigger story in your habits over time."
        case .habitInsights:
            return "Spot the habits that deserve a little more attention."
        case .habitReflections:
            return "Capture how a habit felt, not just whether it happened."
        case .advancedWidgets:
            return "Keep HabitQuest close with more glanceable widgets."
        case .premiumThemes:
            return "Make HabitQuest feel a little more like your own."
        case .premiumAppIcons:
            return "Choose a calmer Premium app icon for your Home Screen."
        case .advancedCustomization:
            return "Tune the details so the app fits your rhythm better."
        case .advancedGamification:
            return "Make progress feel a little more expressive and rewarding."
        }
    }
}

enum PremiumPromotionalNotificationIdentifiers {
    static let categoryIdentifier = "habitquest.premium.promotional"
    static let requestIdentifier = "habitquest.premium.promotional.current"
    static let userInfoFeatureKey = "feature"
    static let userInfoOriginKey = "origin"
    static let userInfoEntryPointKey = "entryPoint"
}

final class PremiumPromotionalNotificationService: PremiumPromotionalNotificationScheduling {
    private let notificationCenter: any UserNotificationCenterServing
    private let preferencesStore: any NotificationPreferencesStoring
    private let premiumEntitlementService: PremiumEntitlementService
    private let premiumPromotionManager: PremiumPromotionManager
    private let planner: PremiumPromotionalNotificationPlanner
    private let authorizationStatusProvider: () async -> UNAuthorizationStatus

    init(
        notificationCenter: any UserNotificationCenterServing = UserNotificationCenterAdapter(),
        preferencesStore: any NotificationPreferencesStoring = LocalNotificationPreferencesStore.live(),
        premiumEntitlementService: PremiumEntitlementService = PremiumEntitlementService(accessState: .free),
        premiumPromotionManager: PremiumPromotionManager = PremiumPromotionManager(),
        planner: PremiumPromotionalNotificationPlanner = PremiumPromotionalNotificationPlanner(),
        authorizationStatusProvider: (() async -> UNAuthorizationStatus)? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.preferencesStore = preferencesStore
        self.premiumEntitlementService = premiumEntitlementService
        self.premiumPromotionManager = premiumPromotionManager
        self.planner = planner
        self.authorizationStatusProvider = authorizationStatusProvider ?? {
            await notificationCenter.notificationSettings().authorizationStatus
        }
    }

    func syncPromotionalNotification(for habits: [Habit], now: Date, calendar: Calendar) async {
        let preferences = loadPreferences()

        guard preferences.isEnabled, preferences.arePromotionalNotificationsEnabled else {
            await cancelPromotionalNotifications()
            return
        }

        guard await canSchedulePromotions() else {
            await cancelPromotionalNotifications()
            return
        }

        let context = PremiumPromotionContext(accessState: premiumEntitlementService.accessState, now: now)
        guard premiumPromotionManager.shouldPresentUnsolicitedPromotion(context: context) else {
            return
        }

        let pendingIdentifiers = await pendingPromotionIdentifiers()
        guard pendingIdentifiers.isEmpty else {
            return
        }

        guard let suggestion = planner.suggestion(for: habits, now: now, calendar: calendar) else {
            return
        }

        let scheduledDate = suggestion.triggerDate
        let quietAdjustedDate = preferences.quietHours.nextAllowedDate(after: scheduledDate, calendar: calendar)

        let payload = suggestion.payload
        let content = UNMutableNotificationContent()
        content.title = payload.notificationTitle
        content.body = payload.notificationBody
        content.sound = .default
        content.categoryIdentifier = PremiumPromotionalNotificationIdentifiers.categoryIdentifier
        content.userInfo = [
            PremiumPromotionalNotificationIdentifiers.userInfoFeatureKey: payload.feature.rawValue,
            PremiumPromotionalNotificationIdentifiers.userInfoOriginKey: payload.origin.rawValue,
            PremiumPromotionalNotificationIdentifiers.userInfoEntryPointKey: payload.entryPoint
        ]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: quietAdjustedDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: PremiumPromotionalNotificationIdentifiers.requestIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            premiumPromotionManager.recordUnsolicitedPromotionPresented(at: now)
        } catch {
            return
        }
    }

    func cancelPromotionalNotifications() async {
        let identifiers = await pendingPromotionIdentifiers()
        guard !identifiers.isEmpty else {
            return
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func loadPreferences() -> HabitQuestNotificationPreferences {
        (try? preferencesStore.loadPreferences()) ?? .default
    }

    private func canSchedulePromotions() async -> Bool {
        guard !premiumEntitlementService.accessState.isPremiumOrTrial else {
            return false
        }

        // Promotional notifications should only ever ride along with the user's
        // existing notification permissions. We do not request permission here.
        switch await authorizationStatusProvider() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func pendingPromotionIdentifiers() async -> [String] {
        let identifiers = await notificationCenter.pendingNotificationIdentifiers()
        return identifiers.filter { $0.hasPrefix("habitquest.premium.promotional") }
    }
}

struct NoOpPremiumPromotionalNotificationService: PremiumPromotionalNotificationScheduling {
    func syncPromotionalNotification(for habits: [Habit], now: Date, calendar: Calendar) async {}

    func cancelPromotionalNotifications() async {}
}

struct PremiumPromotionalNotificationPlanner {
    func suggestion(
        for habits: [Habit],
        now: Date,
        calendar: Calendar
    ) -> PremiumPromotionalNotificationSuggestion? {
        let activeHabits = habits.filter { !$0.isArchived && !$0.isPaused }
        guard !activeHabits.isEmpty else {
            return nil
        }

        let hasMixedRhythms = Set(activeHabits.map(\.dailyRhythm)).count >= 2
        let hasReminderHeavyHabits = activeHabits.contains { ($0.reminderConfiguration?.rules.count ?? 0) > 0 }
        let manyHabits = activeHabits.count >= 5

        if manyHabits && hasMixedRhythms {
            return PremiumPromotionalNotificationSuggestion(
                payload: PremiumPromotionalNotificationPayload(
                    feature: .advancedRoutines,
                    origin: .today
                ),
                triggerDate: self.triggerDate(for: now, calendar: calendar)
            )
        }

        if hasReminderHeavyHabits {
            return PremiumPromotionalNotificationSuggestion(
                payload: PremiumPromotionalNotificationPayload(
                    feature: .multipleReminders,
                    origin: .habits
                ),
                triggerDate: self.triggerDate(for: now, calendar: calendar)
            )
        }

        if activeHabits.count >= 3 {
            return PremiumPromotionalNotificationSuggestion(
                payload: PremiumPromotionalNotificationPayload(
                    feature: .advancedAnalytics,
                    origin: .analytics
                ),
                triggerDate: self.triggerDate(for: now, calendar: calendar)
            )
        }

        return PremiumPromotionalNotificationSuggestion(
            payload: PremiumPromotionalNotificationPayload(
                feature: .premiumThemes,
                origin: .profile
            ),
            triggerDate: self.triggerDate(for: now, calendar: calendar)
        )
    }

    private func triggerDate(for now: Date, calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
    }
}

struct PremiumPromotionalNotificationSuggestion {
    let payload: PremiumPromotionalNotificationPayload
    let triggerDate: Date
}

final class PremiumPromotionRouter: ObservableObject, @unchecked Sendable {
    static let shared = PremiumPromotionRouter()

    @Published var pendingGateDescriptor: PremiumFeatureGateDescriptor?

    func present(_ descriptor: PremiumFeatureGateDescriptor) {
        pendingGateDescriptor = descriptor
    }

    func present(feature: PremiumFeature, origin: PremiumGatePresentationOrigin, entryPoint: String) {
        pendingGateDescriptor = feature.gateDescriptor(origin: origin, entryPoint: entryPoint)
    }

    func clear() {
        pendingGateDescriptor = nil
    }
}

final class HabitQuestNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = HabitQuestNotificationCenterDelegate(router: PremiumPromotionRouter.shared)

    private let router: PremiumPromotionRouter

    init(router: PremiumPromotionRouter) {
        self.router = router
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.notification.request.content.categoryIdentifier == PremiumPromotionalNotificationIdentifiers.categoryIdentifier else {
            return
        }

        guard let payload = PremiumPromotionalNotificationPayload(notificationUserInfo: response.notification.request.content.userInfo) else {
            return
        }

        Task { @MainActor in
            router.present(payload.descriptor)
        }
    }
}

extension PremiumPromotionalNotificationPayload {
    init?(notificationUserInfo: [AnyHashable: Any]) {
        guard
            let featureRawValue = notificationUserInfo[PremiumPromotionalNotificationIdentifiers.userInfoFeatureKey] as? String,
            let feature = PremiumFeature(rawValue: featureRawValue),
            let originRawValue = notificationUserInfo[PremiumPromotionalNotificationIdentifiers.userInfoOriginKey] as? String,
            let origin = PremiumGatePresentationOrigin(rawValue: originRawValue),
            let entryPoint = notificationUserInfo[PremiumPromotionalNotificationIdentifiers.userInfoEntryPointKey] as? String
        else {
            return nil
        }

        self.init(feature: feature, origin: origin, entryPoint: entryPoint)
    }
}
