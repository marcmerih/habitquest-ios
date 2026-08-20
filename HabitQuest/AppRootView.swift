import SwiftUI
import Foundation

struct AppRootView: View {
    private enum RootPhase {
        case launching
        case main
    }

    let environment: HabitQuestEnvironment
    @ObservedObject private var personalizationStore = HabitQuestPersonalizationStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: RootPhase = .launching

    var body: some View {
        ZStack {
            switch phase {
            case .launching:
                LaunchScreenView()
                    .transition(.opacity)

            case .main:
                MainShellView(environment: environment)
                .transition(.opacity)
            }
        }
        .background(HabitQuestDesignSystem.Palette.background(for: colorScheme).ignoresSafeArea())
        .environment(\.habitQuestEnvironment, environment)
        .task {
            guard phase == .launching else { return }
            environment.premiumPromotionManager.beginSession()
            await environment.subscriptionManager.startIfNeeded()
            try? await Task.sleep(nanoseconds: reduceMotion ? 500_000_000 : 700_000_000)
            await resolveElapsedDays()
            environment.streakFreezeService.syncState()

            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : HabitQuestDesignSystem.Motion.standard) {
                phase = .main
            }

            let habits = (try? environment.habitRepository.fetchHabits()) ?? []
            let states = (try? environment.dailyHabitStateStore.loadStates()) ?? []
            _ = try? environment.achievementService.reconcileAchievements()
            await environment.notificationScheduler.syncReminders(
                for: habits,
                states: states,
                now: environment.dateService.now,
                calendar: environment.dateService.calendar
            )
            await environment.premiumPromotionalNotificationService.syncPromotionalNotification(
                for: habits,
                now: environment.dateService.now,
                calendar: environment.dateService.calendar
            )
            environment.widgetRefreshService.refreshSnapshots()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await environment.subscriptionManager.refreshOnForeground() }
            Task {
                let habits = (try? environment.habitRepository.fetchHabits()) ?? []
                await resolveElapsedDays()
                environment.streakFreezeService.syncState()
                await environment.premiumPromotionalNotificationService.syncPromotionalNotification(
                    for: habits,
                    now: environment.dateService.now,
                    calendar: environment.dateService.calendar
                )
                environment.widgetRefreshService.refreshSnapshots()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task {
                await resolveElapsedDays()
                environment.streakFreezeService.syncState()
                environment.widgetRefreshService.refreshSnapshots()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task {
                await resolveElapsedDays()
                environment.streakFreezeService.syncState()
                environment.widgetRefreshService.refreshSnapshots()
            }
        }
    }

    @MainActor
    private func resolveElapsedDays() async {
        _ = try? environment.dayResolutionService.resolveElapsedDays(
            upTo: environment.dateService.now,
            calendar: environment.dateService.calendar
        )
    }
}
