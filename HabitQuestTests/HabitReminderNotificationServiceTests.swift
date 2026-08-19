import Foundation
import XCTest
@testable import HabitQuest

final class HabitReminderNotificationServiceTests: XCTestCase {
    func testPlannerSchedulesNextOccurrenceAfterCompletedToday() {
        let planner = HabitReminderNotificationPlanner()
        let habit = Habit(
            title: "Stretch",
            schedule: .daily,
            timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)),
            dailyRhythm: .morning,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 30))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let state = DailyHabitState(
            habitID: habit.id,
            date: Self.todayMorning,
            status: .completed,
            completedAt: Self.todayNineThirty,
            deckPriority: 10,
            currentPass: 1
        )

        let plans = planner.nextPlans(
            for: habit,
            state: state,
            now: Self.todayNineThirty,
            calendar: Self.calendar,
            rhythmConfiguration: .default,
            quietHours: .default
        )

        XCTAssertEqual(plans.count, 1)
        XCTAssertTrue(plans[0].identifier.contains(habit.id.uuidString))
        XCTAssertEqual(
            Self.calendar.component(.day, from: plans[0].triggerDate),
            Self.calendar.component(.day, from: Self.tomorrowMorning)
        )
        XCTAssertEqual(
            Self.calendar.component(.hour, from: plans[0].triggerDate),
            8
        )
        XCTAssertEqual(
            Self.calendar.component(.minute, from: plans[0].triggerDate),
            30
        )
    }

    func testPlannerShiftsReminderOutOfQuietHours() {
        let planner = HabitReminderNotificationPlanner()
        let habit = Habit(
            title: "Tea",
            schedule: .daily,
            dailyRhythm: .evening,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 6, minute: 30))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let plans = planner.nextPlans(
            for: habit,
            state: nil,
            now: Self.todaySixFifteen,
            calendar: Self.calendar,
            rhythmConfiguration: .default,
            quietHours: .default
        )

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(Self.calendar.component(.hour, from: plans[0].triggerDate), 7)
        XCTAssertEqual(Self.calendar.component(.minute, from: plans[0].triggerDate), 0)
        XCTAssertEqual(
            plans[0].body,
            "Your evening habit “Tea” is waiting whenever you're ready."
        )
    }

    func testPlannerSkipsPausedAndArchivedHabits() {
        let planner = HabitReminderNotificationPlanner()
        let pausedHabit = Habit(
            title: "Walk",
            isPaused: true,
            schedule: .daily,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 0))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let archivedHabit = Habit(
            title: "Journal",
            isArchived: true,
            schedule: .daily,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 0))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        XCTAssertTrue(
            planner.nextPlans(
                for: pausedHabit,
                state: nil,
                now: Self.todayMorning,
                calendar: Self.calendar,
                rhythmConfiguration: .default,
                quietHours: .default
            ).isEmpty
        )
        XCTAssertTrue(
            planner.nextPlans(
                for: archivedHabit,
                state: nil,
                now: Self.todayMorning,
                calendar: Self.calendar,
                rhythmConfiguration: .default,
                quietHours: .default
            ).isEmpty
        )
    }

    func testCancelRemindersRemovesMatchingHabitIdentifiersOnly() async {
        let center = MockNotificationCenter()
        let preferencesStore = LocalNotificationPreferencesStore.inMemory()
        let service = HabitReminderNotificationService(
            notificationCenter: center,
            preferencesStore: preferencesStore,
            rhythmConfiguration: .default
        )

        let habitID = UUID()
        center.pendingIdentifiers = [
            "habit-reminder-\(habitID.uuidString)-2026-08-16-r0",
            "habit-reminder-\(habitID.uuidString)-2026-08-17-r0",
            "habit-reminder-\(UUID().uuidString)-2026-08-16-r0"
        ]

        await service.cancelReminders(for: habitID)

        XCTAssertEqual(center.removedPendingIdentifiers, [
            "habit-reminder-\(habitID.uuidString)-2026-08-16-r0",
            "habit-reminder-\(habitID.uuidString)-2026-08-17-r0"
        ])
        XCTAssertEqual(center.removedDeliveredIdentifiers, center.removedPendingIdentifiers)
    }

    func testGlobalDisableCancelsAllRemindersAndSkipsScheduling() async throws {
        let center = MockNotificationCenter()
        let store = LocalNotificationPreferencesStore.inMemory()
        try store.savePreferences(
            HabitQuestNotificationPreferences(
                isEnabled: false,
                quietHours: .default,
                disabledHabitIDs: []
            )
        )
        let service = HabitReminderNotificationService(
            notificationCenter: center,
            preferencesStore: store,
            rhythmConfiguration: .default
        )

        center.pendingIdentifiers = [
            "habit-reminder-11111111-1111-1111-1111-111111111111-2026-08-16-r0"
        ]

        let habit = Habit(
            title: "Water",
            schedule: .daily,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 0))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        await service.syncReminders(
            for: [habit],
            states: [],
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.removedAllPendingCount, 1)
        XCTAssertEqual(center.removedAllDeliveredCount, 1)
        XCTAssertTrue(center.addedIdentifiers.isEmpty)
    }

    func testDisabledHabitPreferenceSkipsSchedulingAndCancelsHabitOnly() async throws {
        let center = MockNotificationCenter()
        let store = LocalNotificationPreferencesStore.inMemory()
        let habit = Habit(
            title: "Journal",
            schedule: .daily,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 20, minute: 0))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        try store.savePreferences(
            HabitQuestNotificationPreferences(
                isEnabled: true,
                quietHours: .default,
                disabledHabitIDs: [habit.id]
            )
        )

        center.pendingIdentifiers = [
            "habit-reminder-\(habit.id.uuidString)-2026-08-16-r0",
            "habit-reminder-\(UUID().uuidString)-2026-08-16-r0"
        ]

        let service = HabitReminderNotificationService(
            notificationCenter: center,
            preferencesStore: store,
            rhythmConfiguration: .default
        )

        await service.syncReminders(
            for: habit,
            state: nil,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.removedPendingIdentifiers, [
            "habit-reminder-\(habit.id.uuidString)-2026-08-16-r0"
        ])
        XCTAssertEqual(center.removedDeliveredIdentifiers, [
            "habit-reminder-\(habit.id.uuidString)-2026-08-16-r0"
        ])
        XCTAssertTrue(center.addedIdentifiers.isEmpty)
    }

    func testPlannerSkipsHabitWithDisabledReminderConfiguration() {
        let planner = HabitReminderNotificationPlanner()
        let habit = Habit(
            title: "Vitamins",
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: false,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 0))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let plans = planner.nextPlans(
            for: habit,
            state: nil,
            now: Self.todayMorning,
            calendar: Self.calendar,
            rhythmConfiguration: .default,
            quietHours: .default
        )

        XCTAssertTrue(plans.isEmpty)
    }

    func testPremiumAdvancedRemindersScheduleMultiplePrimaryAndFollowUps() async {
        let center = MockNotificationCenter()
        let premiumEntitlementService = PremiumEntitlementService(accessState: .premium)
        let service = HabitReminderNotificationService(
            notificationCenter: center,
            preferencesStore: LocalNotificationPreferencesStore.inMemory(),
            premiumEntitlementProvider: premiumEntitlementService
        )
        let advancedConfiguration = HabitAdvancedReminderConfiguration(
            isEnabled: true,
            primaryReminderTimes: [
                HabitClockTime(hour: 8, minute: 0),
                HabitClockTime(hour: 12, minute: 0)
            ],
            reminderWindow: HabitTimeWindow(
                start: HabitClockTime(hour: 7, minute: 30),
                end: HabitClockTime(hour: 13, minute: 0)
            ),
            followUpDelayMinutes: 60,
            followUpCount: 1,
            routineAwareMode: .dailyRhythm,
            adaptiveTimingEnabled: false
        )
        let habit = Habit(
            title: "Stretch",
            schedule: .daily,
            dailyRhythm: .morning,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [],
                advancedConfiguration: advancedConfiguration
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        await service.syncReminders(
            for: habit,
            state: nil,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.addedRequests.count, 4)
        XCTAssertTrue(center.addedIdentifiers.contains(where: { $0.contains("-advanced-0") }))
        XCTAssertTrue(center.addedIdentifiers.contains(where: { $0.contains("-advanced-1") }))
        XCTAssertTrue(center.addedIdentifiers.contains(where: { $0.contains("-followup-1") }))
        XCTAssertTrue(center.addedIdentifiers.contains(where: { $0.contains("-followup-11") }))
    }

    func testPremiumExpiryFallsBackToBasicReminderConfiguration() async {
        let center = MockNotificationCenter()
        let freeEntitlementService = PremiumEntitlementService(accessState: .free)
        let advancedConfiguration = HabitAdvancedReminderConfiguration(
            isEnabled: true,
            primaryReminderTimes: [
                HabitClockTime(hour: 8, minute: 0),
                HabitClockTime(hour: 12, minute: 0)
            ],
            reminderWindow: HabitTimeWindow(
                start: HabitClockTime(hour: 7, minute: 30),
                end: HabitClockTime(hour: 13, minute: 0)
            ),
            followUpDelayMinutes: 60,
            followUpCount: 1,
            routineAwareMode: .dailyRhythm,
            adaptiveTimingEnabled: false
        )
        let habit = Habit(
            title: "Journal",
            schedule: .daily,
            dailyRhythm: .evening,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 20, minute: 30))],
                advancedConfiguration: advancedConfiguration
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let service = HabitReminderNotificationService(
            notificationCenter: center,
            preferencesStore: LocalNotificationPreferencesStore.inMemory(),
            premiumEntitlementProvider: freeEntitlementService
        )

        await service.syncReminders(
            for: habit,
            state: nil,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedIdentifiers.count, 1)

        guard let trigger = center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger else {
            return XCTFail("Expected a calendar trigger")
        }

        XCTAssertEqual(trigger.dateComponents.hour, 20)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
    }

    func testAdvancedRemindersCanFollowAssignedDaySections() async throws {
        let center = MockNotificationCenter()
        let premiumEntitlementService = PremiumEntitlementService(accessState: .premium)
        let sectionStore = LocalHabitDaySectionStore.inMemory()
        let section = HabitDaySection(
            name: "Deep Work",
            order: 0,
            icon: "💻",
            timeMetadata: HabitDaySectionTimeMetadata(
                start: HabitClockTime(hour: 14, minute: 0),
                end: HabitClockTime(hour: 16, minute: 0)
            ),
            isActive: true,
            period: nil
        )
        try sectionStore.saveSections([section])

        let habit = Habit(
            title: "Planning",
            schedule: .daily,
            dailyRhythm: .day,
            daySectionID: section.id,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [],
                advancedConfiguration: HabitAdvancedReminderConfiguration(
                    isEnabled: true,
                    primaryReminderTimes: [],
                    reminderWindow: nil,
                    followUpDelayMinutes: 60,
                    followUpCount: 0,
                    routineAwareMode: .assignedDaySection,
                    adaptiveTimingEnabled: false
                )
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )
        let service = HabitReminderNotificationService(
            notificationCenter: center,
            preferencesStore: LocalNotificationPreferencesStore.inMemory(),
            daySectionStore: sectionStore,
            premiumEntitlementProvider: premiumEntitlementService
        )

        await service.syncReminders(
            for: habit,
            state: nil,
            now: Self.todayMorning,
            calendar: Self.calendar
        )

        XCTAssertEqual(center.addedRequests.count, 3)
        let triggerHours = center.addedRequests.compactMap { request -> Int? in
            (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour
        }
        XCTAssertEqual(triggerHours.sorted(), [14, 15, 16])
    }

    func testQuietHoursCrossingMidnightShiftToMorningWindow() {
        let quietHours = NotificationQuietHours(
            isEnabled: true,
            start: HabitClockTime(hour: 22, minute: 0),
            end: HabitClockTime(hour: 7, minute: 0)
        )
        let planner = HabitReminderNotificationPlanner()
        let habit = Habit(
            title: "Sleep",
            schedule: .daily,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 23, minute: 15))]
            ),
            createdAt: Self.todayMorning,
            updatedAt: Self.todayMorning
        )

        let plans = planner.nextPlans(
            for: habit,
            state: nil,
            now: Self.todayNineThirty,
            calendar: Self.calendar,
            rhythmConfiguration: .default,
            quietHours: quietHours
        )

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(Self.calendar.component(.hour, from: plans[0].triggerDate), 7)
        XCTAssertEqual(Self.calendar.component(.minute, from: plans[0].triggerDate), 0)
        XCTAssertEqual(
            Self.calendar.component(.day, from: plans[0].triggerDate),
            Self.calendar.component(.day, from: Self.tomorrowMorning)
        )
    }

    func testNotificationPreferencesPersistLocally() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HabitQuestNotificationPreferencesTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        let store = LocalNotificationPreferencesStore(storageURL: directoryURL)
        let habitID = UUID()
        let preferences = HabitQuestNotificationPreferences(
            isEnabled: false,
            quietHours: NotificationQuietHours(
                isEnabled: true,
                start: HabitClockTime(hour: 21, minute: 30),
                end: HabitClockTime(hour: 6, minute: 45)
            ),
            disabledHabitIDs: [habitID]
        )

        try store.savePreferences(preferences)

        let reloadedStore = LocalNotificationPreferencesStore(storageURL: directoryURL)
        let loadedPreferences = try reloadedStore.loadPreferences()

        XCTAssertEqual(loadedPreferences, preferences)
        XCTAssertFalse(loadedPreferences.isEnabled)
        XCTAssertFalse(loadedPreferences.isHabitRemindersEnabled(for: habitID))
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let todayMorning = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 0)
    private static let todayNineThirty = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 30)
    private static let todaySixFifteen = makeDate(year: 2026, month: 8, day: 16, hour: 6, minute: 15)
    private static let tomorrowMorning = makeDate(year: 2026, month: 8, day: 17, hour: 8, minute: 0)

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
    var removedAllPendingCount = 0
    var removedAllDeliveredCount = 0
    var addedIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []

    func notificationSettings() async -> UNNotificationSettings {
        fatalError("notificationSettings() not used in these tests")
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        fatalError("requestAuthorization(options:) not used in these tests")
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        addedIdentifiers.append(request.identifier)
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

    func removeAllPendingNotificationRequests() {
        removedAllPendingCount += 1
    }

    func removeAllDeliveredNotifications() {
        removedAllDeliveredCount += 1
    }
}
