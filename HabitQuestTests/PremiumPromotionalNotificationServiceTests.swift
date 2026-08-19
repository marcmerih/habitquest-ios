import Foundation
import UserNotifications
import XCTest
@testable import HabitQuest

final class PremiumPromotionalNotificationServiceTests: XCTestCase {
    func testPromotionalPreferenceDefaultsAndPersistsLocally() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HabitQuestPromotionalNotificationPreferencesTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: false)

        let store = LocalNotificationPreferencesStore(storageURL: directoryURL)
        var preferences = try store.loadPreferences()

        XCTAssertFalse(preferences.arePromotionalNotificationsEnabled)

        preferences.setPromotionalNotificationsEnabled(true)
        try store.savePreferences(preferences)

        let reloadedStore = LocalNotificationPreferencesStore(storageURL: directoryURL)
        let reloadedPreferences = try reloadedStore.loadPreferences()

        XCTAssertTrue(reloadedPreferences.arePromotionalNotificationsEnabled)
        XCTAssertEqual(reloadedPreferences, preferences)
    }

    func testPlannerSuggestsRoutinesForMixedBusyHabits() {
        let planner = PremiumPromotionalNotificationPlanner()
        let habits = [
            habit("Hydrate", rhythm: .anytime),
            habit("Meditate", rhythm: .morning),
            habit("Workout", rhythm: .morning),
            habit("Read", rhythm: .evening),
            habit("Journal", rhythm: .anytime)
        ]

        let suggestion = planner.suggestion(
            for: habits,
            now: Self.now,
            calendar: Self.calendar
        )

        XCTAssertEqual(suggestion?.payload.feature, .advancedRoutines)
        XCTAssertEqual(Self.calendar.component(.hour, from: suggestion!.triggerDate), 10)
    }

    func testServiceSchedulesRarePromoWhenEligible() async {
        let center = MockNotificationCenter()
        let preferencesStore = LocalNotificationPreferencesStore.inMemory()
        try? preferencesStore.savePreferences(
            HabitQuestNotificationPreferences(
                isEnabled: true,
                arePromotionalNotificationsEnabled: true,
                quietHours: NotificationQuietHours(
                    isEnabled: true,
                    start: HabitClockTime(hour: 22),
                    end: HabitClockTime(hour: 7)
                ),
                disabledHabitIDs: []
            )
        )
        let manager = PremiumPromotionManager(userDefaults: UserDefaults(suiteName: Self.suiteName) ?? .standard, clock: FixedDateService(now: Self.now, calendar: Self.calendar))
        let service = PremiumPromotionalNotificationService(
            notificationCenter: center,
            preferencesStore: preferencesStore,
            premiumEntitlementService: PremiumEntitlementService(accessState: .free),
            premiumPromotionManager: manager,
            authorizationStatusProvider: { .authorized }
        )

        await service.syncPromotionalNotification(
            for: [
                habit("Hydrate", rhythm: .anytime),
                habit("Meditate", rhythm: .morning),
                habit("Workout", rhythm: .morning),
                habit("Read", rhythm: .evening),
                habit("Journal", rhythm: .anytime)
            ],
            now: Self.now,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(
            center.addedRequests.first?.content.categoryIdentifier,
            PremiumPromotionalNotificationIdentifiers.categoryIdentifier
        )
        XCTAssertEqual(center.addedRequests.first?.identifier, PremiumPromotionalNotificationIdentifiers.requestIdentifier)

        guard let userInfo = center.addedRequests.first?.content.userInfo,
            let payload = PremiumPromotionalNotificationPayload(notificationUserInfo: userInfo)
        else {
            return XCTFail("Expected a promo payload")
        }

        XCTAssertEqual(payload.feature, .advancedRoutines)
        XCTAssertEqual(manager.state.lastUnsolicitedPromptPresentedAt, Self.now)
    }

    func testServiceCancelsPromosWhenPreferenceDisabledOrPremiumActive() async {
        let center = MockNotificationCenter()
        center.pendingIdentifiers = [PremiumPromotionalNotificationIdentifiers.requestIdentifier]

        let preferencesStore = LocalNotificationPreferencesStore.inMemory()
        try? preferencesStore.savePreferences(
            HabitQuestNotificationPreferences(
                isEnabled: true,
                arePromotionalNotificationsEnabled: false,
                quietHours: .default,
                disabledHabitIDs: []
            )
        )

        let service = PremiumPromotionalNotificationService(
            notificationCenter: center,
            preferencesStore: preferencesStore,
            premiumEntitlementService: PremiumEntitlementService(accessState: .premium),
            authorizationStatusProvider: { .authorized }
        )

        await service.syncPromotionalNotification(
            for: [habit("Read", rhythm: .evening)],
            now: Self.now,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.removedPendingIdentifiers, [PremiumPromotionalNotificationIdentifiers.requestIdentifier])
        XCTAssertEqual(center.removedDeliveredIdentifiers, [PremiumPromotionalNotificationIdentifiers.requestIdentifier])
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testPromotionalPayloadParsesNotificationUserInfo() {
        let payload = PremiumPromotionalNotificationPayload(
            feature: .advancedAnalytics,
            origin: .analytics,
            entryPoint: "Promotional notification"
        )

        let parsed = PremiumPromotionalNotificationPayload(
            notificationUserInfo: [
                PremiumPromotionalNotificationIdentifiers.userInfoFeatureKey: payload.feature.rawValue,
                PremiumPromotionalNotificationIdentifiers.userInfoOriginKey: payload.origin.rawValue,
                PremiumPromotionalNotificationIdentifiers.userInfoEntryPointKey: payload.entryPoint
            ]
        )

        XCTAssertEqual(parsed, payload)
        XCTAssertEqual(parsed?.descriptor.feature, .advancedAnalytics)
    }

    private func habit(_ title: String, rhythm: HabitRhythm) -> Habit {
        Habit(
            title: title,
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: rhythm,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8))]
            ),
            createdAt: Self.now,
            updatedAt: Self.now
        )
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let now = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
    private static let suiteName = "HabitQuest.PremiumPromotionalNotificationServiceTests.\(UUID().uuidString)"

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

private final class MockNotificationCenter: UserNotificationCenterServing {
    var pendingIdentifiers: [String] = []
    var removedPendingIdentifiers: [String] = []
    var removedDeliveredIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []

    func notificationSettings() async -> UNNotificationSettings {
        fatalError("notificationSettings() not used in these tests")
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        fatalError("requestAuthorization(options:) not used in these tests")
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func pendingNotificationIdentifiers() async -> [String] {
        pendingIdentifiers
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPendingNotificationRequests() {}

    func removeAllDeliveredNotifications() {}
}

private struct FixedDateService: DateProviding {
    let now: Date
    let calendar: Calendar
}
