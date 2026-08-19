#if DEBUG
import Foundation
import SwiftUI

struct HabitQuestPreviewContext {
    let environment: HabitQuestEnvironment
    let preferredColorScheme: ColorScheme?
}

enum HabitQuestPreviewScenario: String, CaseIterable {
    case newUser
    case severalActiveHabits
    case morningHeavySchedule
    case eveningHeavySchedule
    case partiallyCompletedDay
    case multipleDeferredHabits
    case completedDay
    case strongMomentum
    case weakMomentum
    case longStreak
    case brokenStreakStrongMomentum
    case richAnalyticsHistory
    case archivedAndPaused
}

struct HabitQuestPreviewHost<Content: View>: View {
    private let context: HabitQuestPreviewContext
    private let content: Content

    init(context: HabitQuestPreviewContext, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.habitQuestEnvironment, context.environment)
            .preferredColorScheme(context.preferredColorScheme)
    }
}

enum HabitQuestPreviewFixtures {
    static func context(for scenario: HabitQuestPreviewScenario) -> HabitQuestPreviewContext {
        let seed = makeSeed(for: scenario)
        let environment = makeEnvironment(from: seed)
        return HabitQuestPreviewContext(
            environment: environment,
            preferredColorScheme: seed.preferredColorScheme
        )
    }

    private struct PreviewSeed {
        let now: Date
        let preferredColorScheme: ColorScheme?
        let habits: [Habit]
        let states: [DailyHabitState]
        let events: [CompletionEvent]
        let notificationPreferences: HabitQuestNotificationPreferences
        let premiumAccessState: PremiumAccessState = .premium
    }

    private static func makeSeed(for scenario: HabitQuestPreviewScenario) -> PreviewSeed {
        switch scenario {
        case .newUser:
            return PreviewSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 9, minute: 0),
                preferredColorScheme: .light,
                habits: [],
                states: [],
                events: [],
                notificationPreferences: .default
            )

        case .severalActiveHabits:
            return starterSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 9, minute: 15),
                preferredColorScheme: .dark,
                habits: [
                    habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
                    habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E"),
                    habit(.workout, title: "Workout", icon: "🏃", category: "Fitness", schedule: .weekly(days: [.monday, .wednesday, .friday]), rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 10))), colorHex: "B9775A"),
                    habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363"),
                    habit(.journal, title: "Journal", icon: "✍️", category: "Reflection", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "7C8B72")
                ]
            )

        case .morningHeavySchedule:
            return starterSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 8, minute: 45),
                preferredColorScheme: .light,
                habits: [
                    habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E"),
                    habit(.stretch, title: "Stretch", icon: "🫶", category: "Mobility", schedule: .daily, rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 11))), colorHex: "8F7A5D"),
                    habit(.vitamins, title: "Take vitamins", icon: "💊", category: "Wellness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 30)), colorHex: "B9775A"),
                    habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
                    habit(.walk, title: "Walk", icon: "🚶", category: "Wellness", schedule: .daily, rhythm: .day, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 12), end: HabitClockTime(hour: 18))), colorHex: "6B8A71")
                ]
            )

        case .eveningHeavySchedule:
            return starterSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 20, minute: 15),
                preferredColorScheme: .dark,
                habits: [
                    habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363"),
                    habit(.skincare, title: "Skincare", icon: "🫧", category: "Care", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 20, minute: 30)), colorHex: "C66A1E"),
                    habit(.reflection, title: "Reflect", icon: "🌙", category: "Mindfulness", schedule: .daily, rhythm: .evening, timeMode: .allDay, colorHex: "7C6D8D"),
                    habit(.walk, title: "Walk", icon: "🚶", category: "Wellness", schedule: .daily, rhythm: .day, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 12), end: HabitClockTime(hour: 18))), colorHex: "6B8A71"),
                    habit(.journal, title: "Journal", icon: "✍️", category: "Reflection", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "7C8B72")
                ]
            )

        case .partiallyCompletedDay:
            let now = date(year: 2026, month: 8, day: 17, hour: 13, minute: 15)
            let habits = [
                habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
                habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E"),
                habit(.walk, title: "Walk", icon: "🚶", category: "Wellness", schedule: .daily, rhythm: .day, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 12), end: HabitClockTime(hour: 18))), colorHex: "6B8A71"),
                habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363"),
                habit(.journal, title: "Journal", icon: "✍️", category: "Reflection", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "7C8B72"),
                habit(.stretch, title: "Stretch", icon: "🫶", category: "Mobility", schedule: .daily, rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 11))), colorHex: "8F7A5D")
            ]

            return PreviewSeed(
                now: now,
                preferredColorScheme: .dark,
                habits: habits,
                states: [
                    completedState(for: habits[0], on: now, at: time(hour: 9, minute: 0, on: now), calendar: calendar),
                    completedState(for: habits[1], on: now, at: time(hour: 8, minute: 5, on: now), calendar: calendar),
                    completedState(for: habits[2], on: now, at: time(hour: 12, minute: 30, on: now), calendar: calendar),
                    deferredState(for: habits[3], on: now, deferredAt: time(hour: 10, minute: 10, on: now), calendar: calendar, deferCount: 1, currentPass: 2, nextEligibleOffsetMinutes: 90),
                    pendingState(for: habits[4], on: now, calendar: calendar),
                    expiredState(for: habits[5], on: now, calendar: calendar)
                ],
                events: [
                    completionEvent(for: habits[0], on: now, at: time(hour: 9, minute: 0, on: now)),
                    completionEvent(for: habits[1], on: now, at: time(hour: 8, minute: 5, on: now)),
                    completionEvent(for: habits[2], on: now, at: time(hour: 12, minute: 30, on: now))
                ],
                notificationPreferences: .default
            )

        case .multipleDeferredHabits:
            let now = date(year: 2026, month: 8, day: 17, hour: 10, minute: 45)
            let habits = [
                habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
                habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E"),
                habit(.walk, title: "Walk", icon: "🚶", category: "Wellness", schedule: .daily, rhythm: .day, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 12), end: HabitClockTime(hour: 18))), colorHex: "6B8A71"),
                habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363"),
                habit(.journal, title: "Journal", icon: "✍️", category: "Reflection", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "7C8B72"),
                habit(.stretch, title: "Stretch", icon: "🫶", category: "Mobility", schedule: .daily, rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 11))), colorHex: "8F7A5D")
            ]

            return PreviewSeed(
                now: now,
                preferredColorScheme: .dark,
                habits: habits,
                states: [
                    deferredState(for: habits[0], on: now, deferredAt: time(hour: 9, minute: 15, on: now), calendar: calendar, deferCount: 1, currentPass: 2, nextEligibleOffsetMinutes: 45),
                    deferredState(for: habits[1], on: now, deferredAt: time(hour: 9, minute: 5, on: now), calendar: calendar, deferCount: 2, currentPass: 3, nextEligibleOffsetMinutes: 60),
                    deferredState(for: habits[2], on: now, deferredAt: time(hour: 9, minute: 20, on: now), calendar: calendar, deferCount: 1, currentPass: 2, nextEligibleOffsetMinutes: 75),
                    pendingState(for: habits[3], on: now, calendar: calendar),
                    pendingState(for: habits[4], on: now, calendar: calendar),
                    completedState(for: habits[5], on: now, at: time(hour: 8, minute: 10, on: now), calendar: calendar)
                ],
                events: [
                    completionEvent(for: habits[5], on: now, at: time(hour: 8, minute: 10, on: now))
                ],
                notificationPreferences: .default
            )

        case .completedDay:
            let now = date(year: 2026, month: 8, day: 17, hour: 21, minute: 30)
            let habits = starterHabits(now: now)
            let states = habits.map { completedState(for: $0, on: now, at: completionTime(for: $0, on: now), calendar: calendar) }
            let events = habits.map { completionEvent(for: $0, on: now, at: completionTime(for: $0, on: now)) }
            return PreviewSeed(
                now: now,
                preferredColorScheme: .dark,
                habits: habits,
                states: states,
                events: events,
                notificationPreferences: .default
            )

        case .strongMomentum:
            return momentumSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 19, minute: 0),
                preferredColorScheme: .dark,
                completedOffsets: Set((-29)...0),
                includeTodayAsIncomplete: false
            )

        case .weakMomentum:
            return momentumSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 19, minute: 0),
                preferredColorScheme: .light,
                completedOffsets: Set([-28, -24, -21, -18, -14, -11, -7, -4, -2, 0]),
                includeTodayAsIncomplete: true
            )

        case .longStreak:
            let now = date(year: 2026, month: 8, day: 17, hour: 9, minute: 0)
            let habit = habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93")
            let completedOffsets = Set((-29)...0)
            let statesAndEvents = historicalStatesAndEvents(
                for: [habit],
                now: now,
                completedOffsets: completedOffsets,
                deferredOffsets: [],
                startOffset: -29,
                endOffset: 0,
                calendar: calendar,
                treatTodayAsPending: false
            )

            return PreviewSeed(
                now: now,
                preferredColorScheme: .dark,
                habits: [habit],
                states: statesAndEvents.states,
                events: statesAndEvents.events,
                notificationPreferences: .default
            )

        case .brokenStreakStrongMomentum:
            return momentumSeed(
                now: date(year: 2026, month: 8, day: 17, hour: 19, minute: 0),
                preferredColorScheme: .dark,
                completedOffsets: Set((-29)...(-1)),
                includeTodayAsIncomplete: true
            )

        case .richAnalyticsHistory:
            return richAnalyticsSeed()

        case .archivedAndPaused:
            let now = date(year: 2026, month: 8, day: 17, hour: 11, minute: 0)
            let active = [
                habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
                habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363"),
                habit(.journal, title: "Journal", icon: "✍️", category: "Reflection", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "7C8B72")
            ]
            let pausedHabit = habit(.stretch, title: "Stretch", icon: "🫶", category: "Mobility", schedule: .daily, rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 11))), colorHex: "8F7A5D", isPaused: true)
            let archivedHabit = habit(.reflection, title: "Archive review", icon: "🗃️", category: "Admin", schedule: .weekly(days: [.sunday]), rhythm: .anytime, timeMode: .allDay, colorHex: "8E8C84", isArchived: true)

            return PreviewSeed(
                now: now,
                preferredColorScheme: .light,
                habits: active + [pausedHabit, archivedHabit],
                states: [
                    completedState(for: active[0], on: now, at: time(hour: 8, minute: 30, on: now), calendar: calendar),
                    pendingState(for: active[1], on: now, calendar: calendar),
                    deferredState(for: active[2], on: now, deferredAt: time(hour: 9, minute: 15, on: now), calendar: calendar, deferCount: 1, currentPass: 2, nextEligibleOffsetMinutes: 60)
                ],
                events: [
                    completionEvent(for: active[0], on: now, at: time(hour: 8, minute: 30, on: now))
                ],
                notificationPreferences: HabitQuestNotificationPreferences(
                    isEnabled: true,
                    quietHours: .default,
                    disabledHabitIDs: [pausedHabit.id]
                )
            )
        }
    }

    private static func starterSeed(
        now: Date,
        preferredColorScheme: ColorScheme?,
        habits: [Habit]
    ) -> PreviewSeed {
        let states = habits.map { pendingState(for: $0, on: now, calendar: calendar) }
        return PreviewSeed(
            now: now,
            preferredColorScheme: preferredColorScheme,
            habits: habits,
            states: states,
            events: [],
            notificationPreferences: .default
        )
    }

    private static func momentumSeed(
        now: Date,
        preferredColorScheme: ColorScheme?,
        completedOffsets: Set<Int>,
        includeTodayAsIncomplete: Bool
    ) -> PreviewSeed {
        let habits = [
            habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
            habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E"),
            habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363")
        ]

        let result = historicalStatesAndEvents(
            for: habits,
            now: now,
            completedOffsets: completedOffsets,
            deferredOffsets: [],
            startOffset: -29,
            endOffset: 0,
            calendar: calendar,
            treatTodayAsPending: includeTodayAsIncomplete
        )

        return PreviewSeed(
            now: now,
            preferredColorScheme: preferredColorScheme,
            habits: habits,
            states: result.states,
            events: result.events,
            notificationPreferences: .default
        )
    }

    private static func richAnalyticsSeed() -> PreviewSeed {
        let now = date(year: 2026, month: 8, day: 17, hour: 20, minute: 0)
        let habits = [
            habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E"),
            habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93"),
            habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363"),
            habit(.walk, title: "Walk", icon: "🚶", category: "Wellness", schedule: .weekly(days: [.monday, .tuesday, .thursday, .saturday]), rhythm: .day, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 12), end: HabitClockTime(hour: 18))), colorHex: "6B8A71"),
            habit(.reflection, title: "Monthly review", icon: "🗓️", category: "Reflection", schedule: .monthly(dayOfMonth: 15), rhythm: .anytime, timeMode: .allDay, colorHex: "7C6D8D"),
            habit(.stretch, title: "Stretch", icon: "🫶", category: "Mobility", schedule: .daily, rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 11))), colorHex: "8F7A5D"),
            habit(.skincare, title: "Skincare", icon: "🫧", category: "Care", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 20, minute: 30)), colorHex: "C66A1E", isPaused: true),
            habit(.archive, title: "Old system", icon: "🗃️", category: "Archive", schedule: .weekly(days: [.sunday]), rhythm: .anytime, timeMode: .allDay, colorHex: "8E8C84", isArchived: true)
        ]

        var states: [DailyHabitState] = []
        var events: [CompletionEvent] = []

        for offset in (-59)...0 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else {
                continue
            }

            for habit in habits where habit.isActive(on: day, calendar: calendar) {
                let scheduled = habit.isScheduled(on: day, calendar: calendar)
                guard scheduled else {
                    continue
                }

                let completionTime = completionTime(for: habit, on: day)
                let shouldComplete = shouldCompleteHabit(habit, dayOffset: offset, day: day, calendar: calendar)
                let shouldDefer = shouldDeferHabit(habit, dayOffset: offset)

                if shouldComplete {
                    states.append(completedState(for: habit, on: day, at: completionTime, calendar: calendar))
                    events.append(completionEvent(for: habit, on: day, at: completionTime))
                } else if shouldDefer {
                    states.append(
                        deferredState(
                            for: habit,
                            on: day,
                            deferredAt: time(hour: 10, minute: 30, on: day),
                            calendar: calendar,
                            deferCount: 1,
                            currentPass: 2,
                            nextEligibleOffsetMinutes: 90
                        )
                    )
                } else {
                    states.append(
                        expiredState(
                            for: habit,
                            on: day,
                            calendar: calendar
                        )
                    )
                }
            }
        }

        let notificationPreferences = HabitQuestNotificationPreferences(
            isEnabled: true,
            quietHours: NotificationQuietHours(
                isEnabled: true,
                start: HabitClockTime(hour: 22, minute: 0),
                end: HabitClockTime(hour: 7, minute: 0)
            ),
            disabledHabitIDs: [habits[6].id]
        )

        return PreviewSeed(
            now: now,
            preferredColorScheme: .dark,
            habits: habits,
            states: states,
            events: events,
            notificationPreferences: notificationPreferences
        )
    }

    private static func shouldCompleteHabit(_ habit: Habit, dayOffset: Int, day: Date, calendar: Calendar) -> Bool {
        switch habit.id {
        case habitID(.meditate):
            return dayOffset % 7 != 0
        case habitID(.hydrate):
            return dayOffset % 6 != 0
        case habitID(.read):
            return dayOffset >= -20 || dayOffset % 5 != 0
        case habitID(.walk):
            return dayOffset % 2 == 0
        case habitID(.reflection):
            return calendar.component(.day, from: day) == 15
        case habitID(.stretch):
            return dayOffset % 4 != 0
        default:
            return false
        }
    }

    private static func shouldDeferHabit(_ habit: Habit, dayOffset: Int) -> Bool {
        switch habit.id {
        case habitID(.hydrate):
            return dayOffset % 10 == 0
        case habitID(.read):
            return dayOffset % 9 == 0
        case habitID(.walk):
            return dayOffset % 11 == 0
        default:
            return false
        }
    }

    private static func starterHabits(now: Date) -> [Habit] {
        [
            habit(.hydrate, title: "Hydrate", icon: "💧", category: "Wellness", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "6D7E93", createdAt: now.addingTimeInterval(-86_400 * 30)),
            habit(.meditate, title: "Meditate", icon: "🧘", category: "Mindfulness", schedule: .daily, rhythm: .morning, timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)), colorHex: "C66A1E", createdAt: now.addingTimeInterval(-86_400 * 30)),
            habit(.read, title: "Read", icon: "📖", category: "Learning", schedule: .daily, rhythm: .evening, timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)), colorHex: "B99363", createdAt: now.addingTimeInterval(-86_400 * 30)),
            habit(.journal, title: "Journal", icon: "✍️", category: "Reflection", schedule: .daily, rhythm: .anytime, timeMode: .allDay, colorHex: "7C8B72", createdAt: now.addingTimeInterval(-86_400 * 30)),
            habit(.stretch, title: "Stretch", icon: "🫶", category: "Mobility", schedule: .daily, rhythm: .morning, timeMode: .timeWindow(HabitTimeWindow(start: HabitClockTime(hour: 6), end: HabitClockTime(hour: 11))), colorHex: "8F7A5D", createdAt: now.addingTimeInterval(-86_400 * 30))
        ]
    }

    private static func makeEnvironment(from seed: PreviewSeed) -> HabitQuestEnvironment {
        let calendar = calendar
        let dateService = PreviewDateService(now: seed.now, calendar: calendar)
        let habitRepository = LocalHabitRepository.inMemory()
        let habitDaySectionStore = LocalHabitDaySectionStore.inMemory()
        let dailyHabitStateStore = LocalDailyHabitStateStore.inMemory()
        let completionEventStore = LocalCompletionEventStore.inMemory()
        let progressionStore = LocalHabitProgressionStore.inMemory()
        let achievementStore = LocalHabitAchievementStore.inMemory()
        let notificationPreferencesStore = LocalNotificationPreferencesStore.inMemory()
        let personalizationStore = HabitQuestPersonalizationStore.shared
        let widgetSnapshotStore = HabitQuestWidgetSnapshotStore(
            userDefaults: UserDefaults(suiteName: "habitquest.preview.widgets") ?? .standard
        )
        let premiumPromotionRouter = PremiumPromotionRouter()
        let premiumPromotionManager = PremiumPromotionManager(
            userDefaults: UserDefaults(suiteName: "habitquest.preview.promotions") ?? .standard,
            clock: dateService
        )
        let premiumEntitlementService = PremiumEntitlementService(
            accessState: seed.premiumAccessState,
            personalizationStore: personalizationStore,
            widgetSnapshotStore: widgetSnapshotStore
        )
        let subscriptionManager = SubscriptionManager(
            client: PreviewSubscriptionStoreKitClient(accessState: seed.premiumAccessState),
            entitlementService: premiumEntitlementService
        )
        let dailyHabitInstanceEngine = DailyHabitInstanceEngine()
        let achievementService = HabitAchievementService(
            achievementStore: achievementStore,
            habitRepository: habitRepository,
            completionEventStore: completionEventStore,
            dailyHabitStateStore: dailyHabitStateStore,
            progressionStore: progressionStore,
            dateService: dateService,
            evaluator: HabitMilestoneEvaluator()
        )

        do {
            try seed.habits.forEach { try habitRepository.createHabit($0) }
            try dailyHabitStateStore.saveStates(seed.states)
            try completionEventStore.saveEvents(seed.events)

            let progression = HabitProgressionCalculator().state(
                from: seed.habits,
                completionEvents: seed.events
            )
            try progressionStore.saveProgression(progression)

            let achievements = HabitMilestoneEvaluator().evaluate(
                for: seed.habits,
                completionEvents: seed.events,
                dailyStates: seed.states,
                progression: progression,
                at: seed.now,
                calendar: calendar
            )
            try achievementStore.saveAchievements(achievements)

            try notificationPreferencesStore.savePreferences(seed.notificationPreferences)
        } catch {
            preconditionFailure("Unable to build HabitQuest preview fixtures: \(error)")
        }

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

        let rhythmConfiguration: DailyRhythmConfiguration = .default
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

        return HabitQuestEnvironment(
            dateService: dateService,
            hapticService: NoOpHapticService(),
            notificationScheduler: NoOpNotificationScheduler(),
            premiumPromotionalNotificationService: NoOpPremiumPromotionalNotificationService(),
            notificationPreferencesStore: notificationPreferencesStore,
            analyticsTracker: NoOpAnalyticsTracker(),
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
    }

    private static func historicalStatesAndEvents(
        for habits: [Habit],
        now: Date,
        completedOffsets: Set<Int>,
        deferredOffsets: Set<Int>,
        startOffset: Int,
        endOffset: Int,
        calendar: Calendar,
        treatTodayAsPending: Bool
    ) -> (states: [DailyHabitState], events: [CompletionEvent]) {
        var states: [DailyHabitState] = []
        var events: [CompletionEvent] = []

        for offset in startOffset...endOffset {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else {
                continue
            }

            for habit in habits where habit.isScheduled(on: day, calendar: calendar) {
                if completedOffsets.contains(offset) {
                    let completedAt = completionTime(for: habit, on: day)
                    states.append(completedState(for: habit, on: day, at: completedAt, calendar: calendar))
                    events.append(completionEvent(for: habit, on: day, at: completedAt))
                } else if deferredOffsets.contains(offset) {
                    states.append(
                        deferredState(
                            for: habit,
                            on: day,
                            deferredAt: time(hour: 10, minute: 30, on: day),
                            calendar: calendar,
                            deferCount: 1,
                            currentPass: 2,
                            nextEligibleOffsetMinutes: 90
                        )
                    )
                } else if offset == 0 && treatTodayAsPending {
                    states.append(pendingState(for: habit, on: day, calendar: calendar))
                } else {
                    states.append(expiredState(for: habit, on: day, calendar: calendar))
                }
            }
        }

        return (states, events)
    }

    private static func completionTime(for habit: Habit, on day: Date) -> Date {
        switch habit.timeMode {
        case .allDay:
            return time(hour: 9, minute: 0, on: day)
        case .specificTime(let clockTime):
            return time(hour: clockTime.hour, minute: clockTime.minute, on: day)
        case .timeWindow(let window):
            return time(hour: window.start.hour, minute: window.start.minute, on: day)
        }
    }

    private static func completedState(for habit: Habit, on day: Date, at completedAt: Date, calendar: Calendar) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: day),
            status: .completed,
            completedAt: completedAt,
            deckPriority: deckPriority(for: habit),
            currentPass: 1
        )
    }

    private static func pendingState(for habit: Habit, on day: Date, calendar: Calendar) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: day),
            status: .pending,
            deckPriority: deckPriority(for: habit),
            currentPass: 1
        )
    }

    private static func expiredState(for habit: Habit, on day: Date, calendar: Calendar) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: day),
            status: .expired,
            deckPriority: deckPriority(for: habit),
            currentPass: 1
        )
    }

    private static func deferredState(
        for habit: Habit,
        on day: Date,
        deferredAt: Date,
        calendar: Calendar,
        deferCount: Int,
        currentPass: Int,
        nextEligibleOffsetMinutes: Int
    ) -> DailyHabitState {
        DailyHabitState(
            habitID: habit.id,
            date: calendar.startOfDay(for: day),
            status: .deferred,
            deferCount: deferCount,
            lastDeferredAt: deferredAt,
            deckPriority: deckPriority(for: habit),
            currentPass: currentPass,
            nextEligibleAt: calendar.date(byAdding: .minute, value: nextEligibleOffsetMinutes, to: deferredAt)
        )
    }

    private static func completionEvent(for habit: Habit, on day: Date, at completedAt: Date) -> CompletionEvent {
        CompletionEvent(
            habitID: habit.id,
            timestamp: completedAt,
            logicalCompletionDate: calendar.startOfDay(for: day),
            source: .manualHabitAction
        )
    }

    private static func habit(
        _ id: PreviewHabitID,
        title: String,
        icon: String,
        category: String,
        schedule: HabitSchedule,
        rhythm: HabitRhythm,
        timeMode: HabitTimeMode,
        colorHex: String,
        isArchived: Bool = false,
        isPaused: Bool = false,
        createdAt: Date = date(year: 2026, month: 7, day: 1, hour: 9, minute: 0)
    ) -> Habit {
        Habit(
            id: habitID(id),
            title: title,
            icon: icon,
            colorHex: colorHex,
            category: category,
            isArchived: isArchived,
            isPaused: isPaused,
            schedule: schedule,
            timeMode: timeMode,
            dailyRhythm: rhythm,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 9, minute: 0))]
            ),
            difficulty: 2,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private static func deckPriority(for habit: Habit) -> Int {
        switch habit.dailyRhythm {
        case .morning:
            return 18
        case .day:
            return 14
        case .evening:
            return 12
        case .anytime:
            return 10
        }
    }

    private static func habitID(_ id: PreviewHabitID) -> UUID {
        switch id {
        case .hydrate:
            return UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        case .meditate:
            return UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        case .workout:
            return UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        case .read:
            return UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        case .journal:
            return UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        case .walk:
            return UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        case .stretch:
            return UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        case .vitamins:
            return UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        case .skincare:
            return UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        case .reflection:
            return UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        case .archive:
            return UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        }
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
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

    private static func time(hour: Int, minute: Int, on day: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components.date ?? day
    }
}

private struct PreviewDateService: DateProviding {
    let now: Date
    let calendar: Calendar
}

private final class PreviewSubscriptionStoreKitClient: SubscriptionStoreKitClient, @unchecked Sendable {
    private let accessState: PremiumAccessState
    private let products: [SubscriptionProduct]

    init(accessState: PremiumAccessState) {
        self.accessState = accessState
        self.products = [
            SubscriptionProduct(
                id: SubscriptionCatalog.monthlyProductID,
                displayName: "HabitQuest Premium Monthly",
                displayPrice: "$6.99",
                subscriptionPeriodDescription: "1 month",
                introductoryOfferDescription: "Free trial",
                subscriptionGroupDisplayName: "HabitQuest Premium"
            ),
            SubscriptionProduct(
                id: SubscriptionCatalog.annualProductID,
                displayName: "HabitQuest Premium Annual",
                displayPrice: "$59.99",
                subscriptionPeriodDescription: "1 year",
                introductoryOfferDescription: "Free trial",
                subscriptionGroupDisplayName: "HabitQuest Premium"
            )
        ]
    }

    func loadProducts() async throws -> [SubscriptionProduct] {
        products
    }

    func refreshAccessState() async throws -> PremiumAccessState {
        accessState
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard products.contains(where: { $0.id == productID }) else {
            throw SubscriptionManagerError.unknownProduct(productID)
        }

        return .success
    }

    func restorePurchases() async throws {}

    func observeTransactionUpdates(onUpdate: @escaping @Sendable () async -> Void) -> SubscriptionUpdateObservation {
        SubscriptionUpdateObservation(cancellation: {})
    }
}

private enum PreviewHabitID {
    case hydrate
    case meditate
    case workout
    case read
    case journal
    case walk
    case stretch
    case vitamins
    case skincare
    case reflection
    case archive
}

private struct HabitQuestTodayPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .newUser)) {
                TodayFeatureView()
            }
            .previewDisplayName("Today - New User")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .morningHeavySchedule)) {
                TodayFeatureView()
            }
            .previewDisplayName("Today - Morning Focus")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .partiallyCompletedDay)) {
                TodayFeatureView()
            }
            .previewDisplayName("Today - Partially Completed")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .multipleDeferredHabits)) {
                TodayFeatureView()
            }
            .previewDisplayName("Today - Deferred Pass")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .completedDay)) {
                TodayFeatureView()
            }
            .previewDisplayName("Today - Day Complete")
        }
    }
}

private struct HabitQuestHabitsPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .severalActiveHabits)) {
                HabitsFeatureView()
            }
            .previewDisplayName("Habits - Active Library")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .archivedAndPaused)) {
                HabitsFeatureView()
            }
            .previewDisplayName("Habits - Archived And Paused")
        }
    }
}

private struct HabitQuestAnalyticsPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .richAnalyticsHistory)) {
                AnalyticsFeatureView()
            }
            .previewDisplayName("Analytics - Rich History")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .weakMomentum)) {
                AnalyticsFeatureView()
            }
            .previewDisplayName("Analytics - Weak Momentum")

            HabitQuestPreviewHost(context: HabitQuestPreviewFixtures.context(for: .brokenStreakStrongMomentum)) {
                AnalyticsFeatureView()
            }
            .previewDisplayName("Analytics - Broken Streak Strong Momentum")
        }
    }
}

private struct HabitQuestProfilePreviews: PreviewProvider {
    static var previews: some View {
        Group {
            let strongContext = HabitQuestPreviewFixtures.context(for: .strongMomentum)
            HabitQuestPreviewHost(context: strongContext) {
                ProfileFeatureView(
                    subscriptionManager: strongContext.environment.subscriptionManager,
                    onReplayOnboarding: {}
                )
            }
            .previewDisplayName("Profile - Strong Momentum")

            let longContext = HabitQuestPreviewFixtures.context(for: .longStreak)
            HabitQuestPreviewHost(context: longContext) {
                ProfileFeatureView(
                    subscriptionManager: longContext.environment.subscriptionManager,
                    onReplayOnboarding: {}
                )
            }
            .previewDisplayName("Profile - Long Streak")

            let archivedContext = HabitQuestPreviewFixtures.context(for: .archivedAndPaused)
            HabitQuestPreviewHost(context: archivedContext) {
                ProfileFeatureView(
                    subscriptionManager: archivedContext.environment.subscriptionManager,
                    onReplayOnboarding: {}
                )
            }
            .previewDisplayName("Profile - Archived And Paused")
        }
    }
}

private struct HabitQuestOnboardingPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingFlowView(mode: .firstLaunch, onFinish: {})
                .previewDisplayName("Onboarding - First Launch")

            OnboardingFlowView(mode: .replay, onFinish: {})
                .previewDisplayName("Onboarding - Replay")
        }
    }
}
#endif
