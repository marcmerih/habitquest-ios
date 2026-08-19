import Foundation
@preconcurrency import UserNotifications

struct NotificationQuietHours: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var start: HabitClockTime
    var end: HabitClockTime

    static let `default` = NotificationQuietHours(
        isEnabled: true,
        start: HabitClockTime(hour: 22),
        end: HabitClockTime(hour: 7)
    )

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard isEnabled else {
            return false
        }

        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = start.minutesSinceStartOfDay()
        let endMinute = end.minutesSinceStartOfDay()

        if startMinute <= endMinute {
            return (startMinute...endMinute).contains(minuteOfDay)
        }

        return minuteOfDay >= startMinute || minuteOfDay <= endMinute
    }

    func nextAllowedDate(after date: Date, calendar: Calendar) -> Date {
        guard isEnabled else {
            return date
        }

        guard contains(date, calendar: calendar) else {
            return date
        }

        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = start.minutesSinceStartOfDay()
        let endMinute = end.minutesSinceStartOfDay()
        let dayStart = calendar.startOfDay(for: date)

        if startMinute <= endMinute {
            return calendar.date(
                bySettingHour: end.hour,
                minute: end.minute,
                second: 0,
                of: dayStart
            ) ?? date
        }

        if minuteOfDay >= startMinute {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            return calendar.date(
                bySettingHour: end.hour,
                minute: end.minute,
                second: 0,
                of: nextDay
            ) ?? date
        }

        return calendar.date(
            bySettingHour: end.hour,
            minute: end.minute,
            second: 0,
            of: dayStart
        ) ?? date
    }
}

struct HabitReminderNotificationPlan: Equatable, Sendable {
    let identifier: String
    let logicalDate: Date
    let triggerDate: Date
    let title: String
    let body: String
}

struct HabitReminderNotificationPlanner {
    func nextPlans(
        for habit: Habit,
        state: DailyHabitState?,
        now: Date,
        calendar: Calendar,
        rhythmConfiguration: DailyRhythmConfiguration,
        quietHours: NotificationQuietHours = .default,
        premiumEntitlementProvider: any PremiumEntitlementProviding = PremiumEntitlementService(accessState: .free),
        daySectionsByID: [UUID: HabitDaySection] = [:],
        lookAheadDays: Int = 30
    ) -> [HabitReminderNotificationPlan] {
        guard shouldSchedule(for: habit) else {
            return []
        }

        guard let reminderConfiguration = habit.reminderConfiguration,
            reminderConfiguration.isEnabled,
            !reminderConfiguration.rules.isEmpty || reminderConfiguration.advancedConfiguration?.isEnabled == true
        else {
            return []
        }

        let startDate = schedulingStartDate(for: habit, state: state, now: now, calendar: calendar)
        let searchWindow = max(lookAheadDays, 1)
        let canUseAdvancedReminders = premiumEntitlementProvider.canAccess(.multipleReminders)
            || premiumEntitlementProvider.canAccess(.smartReminders)

        let plans: [HabitReminderNotificationPlan]
        if canUseAdvancedReminders,
            let advancedConfiguration = reminderConfiguration.advancedConfiguration,
            advancedConfiguration.isEnabled {
            plans = advancedPlans(
                for: habit,
                state: state,
                now: now,
                calendar: calendar,
                rhythmConfiguration: rhythmConfiguration,
                quietHours: quietHours,
                daySectionsByID: daySectionsByID,
                premiumEntitlementProvider: premiumEntitlementProvider,
                advancedConfiguration: advancedConfiguration,
                lookAheadDays: searchWindow
            )
        } else {
            plans = reminderConfiguration.rules.enumerated().compactMap { index, rule in
                nextPlan(
                    for: rule,
                    index: index,
                    habit: habit,
                    startDate: startDate,
                    now: now,
                    calendar: calendar,
                    rhythmConfiguration: rhythmConfiguration,
                    quietHours: quietHours,
                    lookAheadDays: searchWindow
                )
            }
        }

        return deduplicated(plans)
    }

    private func shouldSchedule(for habit: Habit) -> Bool {
        !habit.isArchived && !habit.isPaused
    }

    private func schedulingStartDate(for habit: Habit, state: DailyHabitState?, now: Date, calendar: Calendar) -> Date {
        guard let state else {
            return now
        }

        if state.status == .completed, calendar.isDate(state.date, inSameDayAs: now) {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        }

        if state.status == .deferred, let nextEligibleAt = state.nextEligibleAt, nextEligibleAt > now {
            return nextEligibleAt
        }

        return now
    }

    private func nextPlan(
        for rule: HabitReminderRule,
        index: Int,
        habit: Habit,
        startDate: Date,
        now: Date,
        calendar: Calendar,
        rhythmConfiguration: DailyRhythmConfiguration,
        quietHours: NotificationQuietHours,
        lookAheadDays: Int
    ) -> HabitReminderNotificationPlan? {
        let startDay = calendar.startOfDay(for: startDate)

        for offset in 0...lookAheadDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else {
                continue
            }

            guard habit.isScheduled(on: day, calendar: calendar) else {
                continue
            }

            guard let proposedDate = triggerDate(
                for: rule,
                habit: habit,
                on: day,
                calendar: calendar,
                rhythmConfiguration: rhythmConfiguration
            ) else {
                continue
            }

            let quietAdjustedDate = quietHours.nextAllowedDate(after: proposedDate, calendar: calendar)
            guard quietAdjustedDate >= now else {
                continue
            }

            let logicalDate = calendar.startOfDay(for: day)
            let identifier = Self.identifier(
                habitID: habit.id,
                logicalDate: logicalDate,
                kind: "basic",
                index: index,
                calendar: calendar
            )

            return HabitReminderNotificationPlan(
                identifier: identifier,
                logicalDate: logicalDate,
                triggerDate: quietAdjustedDate,
                title: "HabitQuest reminder",
                body: body(for: habit)
            )
        }

        return nil
    }

    private func advancedPlans(
        for habit: Habit,
        state: DailyHabitState?,
        now: Date,
        calendar: Calendar,
        rhythmConfiguration: DailyRhythmConfiguration,
        quietHours: NotificationQuietHours,
        daySectionsByID: [UUID: HabitDaySection],
        premiumEntitlementProvider: any PremiumEntitlementProviding,
        advancedConfiguration: HabitAdvancedReminderConfiguration,
        lookAheadDays: Int
    ) -> [HabitReminderNotificationPlan] {
        let startDate = schedulingStartDate(for: habit, state: state, now: now, calendar: calendar)
        let startDay = calendar.startOfDay(for: startDate)

        for offset in 0...lookAheadDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else {
                continue
            }

            guard habit.isScheduled(on: day, calendar: calendar) else {
                continue
            }

            guard let referenceWindow = reminderReferenceWindow(
                for: habit,
                advancedConfiguration: advancedConfiguration,
                daySectionsByID: daySectionsByID,
                premiumEntitlementProvider: premiumEntitlementProvider,
                calendar: calendar,
                rhythmConfiguration: rhythmConfiguration
            ) else {
                continue
            }

            let logicalDate = calendar.startOfDay(for: day)
            let primaryTriggerDates = primaryTriggerDates(
                for: habit,
                on: day,
                logicalDate: logicalDate,
                referenceWindow: referenceWindow,
                advancedConfiguration: advancedConfiguration,
                premiumEntitlementProvider: premiumEntitlementProvider,
                calendar: calendar,
                rhythmConfiguration: rhythmConfiguration
            )

            guard !primaryTriggerDates.isEmpty else {
                continue
            }

            var plans: [HabitReminderNotificationPlan] = []

            for (primaryIndex, triggerDate) in primaryTriggerDates.enumerated() {
                guard let primaryPlan = reminderPlan(
                    habit: habit,
                    logicalDate: logicalDate,
                    triggerDate: triggerDate,
                    kind: "advanced",
                    index: primaryIndex,
                    calendar: calendar,
                    quietHours: quietHours,
                    now: now
                ) else {
                    continue
                }

                plans.append(primaryPlan)

                guard premiumRemindersShouldFollowUp(
                    advancedConfiguration: advancedConfiguration,
                    premiumEntitlementProvider: premiumEntitlementProvider
                ) else {
                    continue
                }

                let followUpDelay = TimeInterval(advancedConfiguration.followUpDelayMinutes * 60)
                guard followUpDelay > 0 else {
                    continue
                }

                for followUpIndex in 1...advancedConfiguration.followUpCount {
                    let followUpTrigger = triggerDate.addingTimeInterval(followUpDelay * Double(followUpIndex))
                    if let followUpPlan = reminderPlan(
                        habit: habit,
                        logicalDate: logicalDate,
                        triggerDate: followUpTrigger,
                        kind: "followup",
                        index: (primaryIndex * 10) + followUpIndex,
                        calendar: calendar,
                        quietHours: quietHours,
                        now: now
                    ) {
                        plans.append(followUpPlan)
                    }
                }
            }

            return plans
        }

        return []
    }

    private func reminderPlan(
        habit: Habit,
        logicalDate: Date,
        triggerDate: Date,
        kind: String,
        index: Int,
        calendar: Calendar,
        quietHours: NotificationQuietHours,
        now: Date
    ) -> HabitReminderNotificationPlan? {
        let quietAdjustedDate = quietHours.nextAllowedDate(after: triggerDate, calendar: calendar)
        guard quietAdjustedDate >= now else {
            return nil
        }

        let identifier = Self.identifier(
            habitID: habit.id,
            logicalDate: logicalDate,
            kind: kind,
            index: index,
            calendar: calendar
        )

        return HabitReminderNotificationPlan(
            identifier: identifier,
            logicalDate: logicalDate,
            triggerDate: quietAdjustedDate,
            title: "HabitQuest reminder",
            body: body(for: habit)
        )
    }

    private func primaryTriggerDates(
        for habit: Habit,
        on day: Date,
        logicalDate: Date,
        referenceWindow: HabitTimeWindow,
        advancedConfiguration: HabitAdvancedReminderConfiguration,
        premiumEntitlementProvider: any PremiumEntitlementProviding,
        calendar: Calendar,
        rhythmConfiguration: DailyRhythmConfiguration
    ) -> [Date] {
        let canUseMultipleReminders = premiumEntitlementProvider.canAccess(.multipleReminders)
        let times: [HabitClockTime]

        if !advancedConfiguration.primaryReminderTimes.isEmpty {
            if canUseMultipleReminders {
                times = advancedConfiguration.primaryReminderTimes
            } else {
                times = [advancedConfiguration.primaryReminderTimes[0]]
            }
        } else if advancedConfiguration.reminderWindow != nil {
            if canUseMultipleReminders {
                times = defaultReminderTimes(for: advancedConfiguration.reminderWindow!)
            } else if let midpoint = advancedConfiguration.reminderWindow.map({ midpointTime(for: DailyRhythmTimeRange(start: $0.start, end: $0.end)) }) {
                times = [midpoint]
            } else {
                times = []
            }
        } else if advancedConfiguration.adaptiveTimingEnabled {
            times = adaptiveReminderTimes(
                for: habit,
                on: day,
                referenceWindow: referenceWindow,
                canUseMultipleReminders: canUseMultipleReminders,
                premiumEntitlementProvider: premiumEntitlementProvider,
                rhythmConfiguration: rhythmConfiguration
            )
        } else {
            if canUseMultipleReminders {
                times = defaultReminderTimes(for: referenceWindow)
            } else {
                times = [midpointTime(for: DailyRhythmTimeRange(start: referenceWindow.start, end: referenceWindow.end))]
            }
        }

        let dayStart = calendar.startOfDay(for: logicalDate)
        let allowedWindow = advancedConfiguration.reminderWindow ?? referenceWindow

        return times.compactMap { time in
            guard let trigger = calendar.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: 0,
                of: dayStart
            ) else {
                return nil
            }

        if !allowedWindow.contains(trigger, calendar: calendar) {
                return nil
            }

            return trigger
        }
    }

    private func defaultReminderTimes(for window: HabitTimeWindow) -> [HabitClockTime] {
        let start = window.start
        let end = window.end

        if start == end {
            return [start]
        }

        let midpoint = midpointTime(for: DailyRhythmTimeRange(start: start, end: end))
        return [start, midpoint, end]
    }

    private func adaptiveReminderTimes(
        for habit: Habit,
        on day: Date,
        referenceWindow: HabitTimeWindow,
        canUseMultipleReminders: Bool,
        premiumEntitlementProvider: any PremiumEntitlementProviding,
        rhythmConfiguration: DailyRhythmConfiguration
    ) -> [HabitClockTime] {
        switch habit.timeMode {
        case .allDay:
            if premiumEntitlementProvider.canAccess(.smartReminders),
                let rhythmWindow = rhythmConfiguration.window(for: habit.dailyRhythm) {
                let window = HabitTimeWindow(start: rhythmWindow.start, end: rhythmWindow.end)
                return canUseMultipleReminders ? defaultReminderTimes(for: window) : [midpointTime(for: DailyRhythmTimeRange(start: window.start, end: window.end))]
            }
            return canUseMultipleReminders ? defaultReminderTimes(for: referenceWindow) : [midpointTime(for: DailyRhythmTimeRange(start: referenceWindow.start, end: referenceWindow.end))]
        case .specificTime(let time):
            return [time]
        case .timeWindow(let window):
            return canUseMultipleReminders ? defaultReminderTimes(for: window) : [midpointTime(for: DailyRhythmTimeRange(start: window.start, end: window.end))]
        }
    }

    private func reminderReferenceWindow(
        for habit: Habit,
        advancedConfiguration: HabitAdvancedReminderConfiguration,
        daySectionsByID: [UUID: HabitDaySection],
        premiumEntitlementProvider: any PremiumEntitlementProviding,
        calendar: Calendar,
        rhythmConfiguration: DailyRhythmConfiguration
    ) -> HabitTimeWindow? {
        if premiumEntitlementProvider.canAccess(.smartReminders),
            advancedConfiguration.routineAwareMode == .assignedDaySection,
            let sectionID = habit.daySectionID,
            let section = daySectionsByID[sectionID],
            let metadata = section.timeMetadata {
            return HabitTimeWindow(start: metadata.start, end: metadata.end)
        }

        if premiumEntitlementProvider.canAccess(.smartReminders),
            advancedConfiguration.routineAwareMode == .dailyRhythm,
            let rhythmWindow = rhythmConfiguration.window(for: habit.dailyRhythm) {
            return HabitTimeWindow(start: rhythmWindow.start, end: rhythmWindow.end)
        }

        switch habit.timeMode {
        case .allDay:
            if let rhythmWindow = rhythmConfiguration.window(for: habit.dailyRhythm) {
                return HabitTimeWindow(start: rhythmWindow.start, end: rhythmWindow.end)
            }

            return HabitTimeWindow(start: HabitClockTime(hour: 12), end: HabitClockTime(hour: 12))
        case .specificTime(let time):
            return HabitTimeWindow(start: time, end: time)
        case .timeWindow(let window):
            return window
        }
    }

    private func premiumRemindersShouldFollowUp(
        advancedConfiguration: HabitAdvancedReminderConfiguration,
        premiumEntitlementProvider: any PremiumEntitlementProviding
    ) -> Bool {
        premiumEntitlementProvider.canAccess(.smartReminders)
            && advancedConfiguration.followUpCount > 0
            && advancedConfiguration.followUpDelayMinutes > 0
    }

    private func deduplicated(_ plans: [HabitReminderNotificationPlan]) -> [HabitReminderNotificationPlan] {
        var seen = Set<String>()

        return plans
            .sorted { lhs, rhs in
                if lhs.triggerDate == rhs.triggerDate {
                    return lhs.identifier < rhs.identifier
                }

                return lhs.triggerDate < rhs.triggerDate
            }
            .filter { plan in
                let key = "\(plan.logicalDate.timeIntervalSinceReferenceDate)-\(plan.triggerDate.timeIntervalSinceReferenceDate)"
                return seen.insert(key).inserted
            }
    }

    private func triggerDate(
        for rule: HabitReminderRule,
        habit: Habit,
        on day: Date,
        calendar: Calendar,
        rhythmConfiguration: DailyRhythmConfiguration
    ) -> Date? {
        switch rule {
        case .atTime(let time):
            return calendar.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: 0,
                of: day
            )
        case .beforeScheduledTime(let minutes):
            let referenceTime = scheduledReferenceTime(for: habit, rhythmConfiguration: rhythmConfiguration)
            guard let referenceDate = calendar.date(
                bySettingHour: referenceTime.hour,
                minute: referenceTime.minute,
                second: 0,
                of: day
            ) else {
                return nil
            }

            return calendar.date(byAdding: .minute, value: -max(minutes, 0), to: referenceDate)
        }
    }

    private func scheduledReferenceTime(
        for habit: Habit,
        rhythmConfiguration: DailyRhythmConfiguration
    ) -> HabitClockTime {
        switch habit.timeMode {
        case .allDay:
            if let window = rhythmConfiguration.window(for: habit.dailyRhythm) {
                return midpointTime(for: window)
            }

            return HabitClockTime(hour: 12, minute: 0)
        case .specificTime(let time):
            return time
        case .timeWindow(let window):
            return window.end
        }
    }

    private func body(for habit: Habit) -> String {
        let habitTitle = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor: String

        switch habit.dailyRhythm {
        case .morning:
            descriptor = "Your morning habit"
        case .day:
            descriptor = "Your daytime habit"
        case .evening:
            descriptor = "Your evening habit"
        case .anytime:
            descriptor = "Your habit"
        }

        return "\(descriptor) “\(habitTitle)” is waiting whenever you're ready."
    }

    private func midpointTime(for range: DailyRhythmTimeRange) -> HabitClockTime {
        let start = range.start.minutesSinceStartOfDay()
        let end = range.end.minutesSinceStartOfDay()

        let midpoint: Int
        if start <= end {
            midpoint = start + ((end - start) / 2)
        } else {
            let duration = (24 * 60 - start) + end
            midpoint = (start + (duration / 2)) % (24 * 60)
        }

        return HabitClockTime(hour: midpoint / 60, minute: midpoint % 60)
    }

    private static func identifier(
        habitID: UUID,
        logicalDate: Date,
        kind: String,
        index: Int,
        calendar: Calendar
    ) -> String {
        "habit-reminder-\(habitID.uuidString)-\(dayKey(for: logicalDate, calendar: calendar))-\(kind)-\(index)"
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

protocol UserNotificationCenterServing {
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationIdentifiers() async -> [String]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
}

final class UserNotificationCenterAdapter: UserNotificationCenterServing {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: options) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func pendingNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
}

protocol NotificationScheduling {
    func syncReminders(for habits: [Habit], states: [DailyHabitState], now: Date, calendar: Calendar) async
    func syncReminders(for habit: Habit, state: DailyHabitState?, now: Date, calendar: Calendar) async
    func cancelReminders(for habitID: UUID) async
    func cancelReminder(for habitID: UUID, logicalDate: Date, calendar: Calendar) async
}

struct NoOpNotificationScheduler: NotificationScheduling {
    func syncReminders(for habits: [Habit], states: [DailyHabitState], now: Date, calendar: Calendar) async {}
    func syncReminders(for habit: Habit, state: DailyHabitState?, now: Date, calendar: Calendar) async {}
    func cancelReminders(for habitID: UUID) async {}
    func cancelReminder(for habitID: UUID, logicalDate: Date, calendar: Calendar) async {}
}

struct HabitReminderNotificationService: NotificationScheduling {
    private let notificationCenter: any UserNotificationCenterServing
    private let preferencesStore: any NotificationPreferencesStoring
    private let daySectionStore: (any HabitDaySectionStoring)?
    private let premiumEntitlementProvider: any PremiumEntitlementProviding
    private let planner: HabitReminderNotificationPlanner
    private let rhythmConfiguration: DailyRhythmConfiguration

    init(
        notificationCenter: any UserNotificationCenterServing = UserNotificationCenterAdapter(),
        preferencesStore: any NotificationPreferencesStoring = LocalNotificationPreferencesStore.live(),
        daySectionStore: (any HabitDaySectionStoring)? = nil,
        premiumEntitlementProvider: any PremiumEntitlementProviding = PremiumEntitlementService(accessState: .free),
        rhythmConfiguration: DailyRhythmConfiguration = .default,
    ) {
        self.notificationCenter = notificationCenter
        self.preferencesStore = preferencesStore
        self.daySectionStore = daySectionStore
        self.premiumEntitlementProvider = premiumEntitlementProvider
        self.planner = HabitReminderNotificationPlanner()
        self.rhythmConfiguration = rhythmConfiguration
    }

    func syncReminders(for habits: [Habit], states: [DailyHabitState], now: Date, calendar: Calendar) async {
        let preferences = loadPreferences()

        guard preferences.isEnabled else {
            await cancelAllNotifications()
            return
        }

        let daySectionsByID = loadDaySections()
        let statesByHabitID = Dictionary(grouping: states, by: \.habitID).compactMapValues { habitStates in
            habitStates.max(by: { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.updatedSortKey < rhs.updatedSortKey
                }

                return lhs.date < rhs.date
            })
        }

        for habit in habits {
            guard preferences.isHabitRemindersEnabled(for: habit.id) else {
                await cancelReminders(for: habit.id)
                continue
            }

            await syncReminders(
                for: habit,
                state: statesByHabitID[habit.id],
                now: now,
                calendar: calendar,
                daySectionsByID: daySectionsByID
            )
        }
    }

    func syncReminders(for habit: Habit, state: DailyHabitState?, now: Date, calendar: Calendar) async {
        await syncReminders(
            for: habit,
            state: state,
            now: now,
            calendar: calendar,
            daySectionsByID: loadDaySections()
        )
    }

    private func syncReminders(
        for habit: Habit,
        state: DailyHabitState?,
        now: Date,
        calendar: Calendar,
        daySectionsByID: [UUID: HabitDaySection]
    ) async {
        let preferences = loadPreferences()

        guard preferences.isEnabled else {
            await cancelAllNotifications()
            return
        }

        guard preferences.isHabitRemindersEnabled(for: habit.id) else {
            await cancelReminders(for: habit.id)
            return
        }

        let identifiers = await habitIdentifiers(for: habit.id)
        await removeNotifications(withIdentifiers: identifiers)

        guard await canScheduleNotifications() else {
            return
        }

        let plans = planner.nextPlans(
            for: habit,
            state: state,
            now: now,
            calendar: calendar,
            rhythmConfiguration: rhythmConfiguration,
            quietHours: preferences.quietHours,
            premiumEntitlementProvider: premiumEntitlementProvider,
            daySectionsByID: daySectionsByID
        )

        for plan in plans {
            await schedule(plan, calendar: calendar)
        }
    }

    func cancelReminders(for habitID: UUID) async {
        let identifiers = await habitIdentifiers(for: habitID)
        await removeNotifications(withIdentifiers: identifiers)
    }

    func cancelReminder(for habitID: UUID, logicalDate: Date, calendar: Calendar) async {
        let prefix = Self.identifierPrefix(
            habitID: habitID,
            logicalDate: logicalDate,
            calendar: calendar
        )
        let identifiers = await habitIdentifiers(withPrefix: prefix)
        await removeNotifications(withIdentifiers: identifiers)
    }

    private func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    private func loadPreferences() -> HabitQuestNotificationPreferences {
        (try? preferencesStore.loadPreferences()) ?? .default
    }

    private func canScheduleNotifications() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func schedule(_ plan: HabitReminderNotificationPlan, calendar: Calendar) async {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: plan.triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            return
        }
    }

    private func removeNotifications(withIdentifiers identifiers: [String]) async {
        guard !identifiers.isEmpty else {
            return
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func habitIdentifiers(for habitID: UUID) async -> [String] {
        let prefix = Self.identifierPrefix(habitID: habitID)
        return await habitIdentifiers(withPrefix: prefix)
    }

    private func habitIdentifiers(withPrefix prefix: String) async -> [String] {
        let identifiers = await notificationCenter.pendingNotificationIdentifiers()
        return identifiers
            .filter { $0.hasPrefix(prefix) }
    }

    private func loadDaySections() -> [UUID: HabitDaySection] {
        guard let daySectionStore else {
            return [:]
        }

        let sections = (try? daySectionStore.loadSections()) ?? []
        return sections.reduce(into: [:]) { result, section in
            result[section.id] = section
        }
    }

    private static func identifierPrefix(habitID: UUID, logicalDate: Date? = nil, calendar: Calendar = .current) -> String {
        let base = "habit-reminder-\(habitID.uuidString)-"
        guard let logicalDate else {
            return base
        }

        let components = calendar.dateComponents([.year, .month, .day], from: logicalDate)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let dayKey = String(format: "%04d-%02d-%02d", year, month, day)
        return "\(base)\(dayKey)-"
    }
}

private extension DailyHabitState {
    var updatedSortKey: Date {
        completedAt ?? lastDeferredAt ?? date
    }
}
