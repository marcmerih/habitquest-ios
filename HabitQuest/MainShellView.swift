import SwiftUI

struct MainShellView: View {
    let environment: HabitQuestEnvironment

    @ObservedObject private var premiumPromotionRouter: PremiumPromotionRouter
    @State private var selectedTab: MainTab = .today
    @State private var isPresentingOnboarding = false
    @State private var isPresentingPremiumTrialIntro = false
    @State private var isPresentingPremiumPaywall = false
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var didEvaluateFirstLaunch = false
    @State private var pendingHabitTemplate: HabitTemplate?
    @AppStorage(HabitQuestOnboardingState.completedKey) private var hasCompletedOnboarding = false
    @AppStorage(HabitQuestPremiumTrialIntroState.presentedKey) private var hasPresentedPremiumTrialIntro = false
    @Environment(\.colorScheme) private var colorScheme

    init(environment: HabitQuestEnvironment) {
        self.environment = environment
        self._premiumPromotionRouter = ObservedObject(wrappedValue: environment.premiumPromotionRouter)
        self._premiumFeatureGateDescriptor = State(initialValue: environment.premiumPromotionRouter.pendingGateDescriptor)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayTabRootView {
                selectedTab = .habits
            }
                .tag(MainTab.today)
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            HabitsTabRootView(pendingTemplate: $pendingHabitTemplate)
                .tag(MainTab.habits)
                .tabItem {
                    Label("Habits", systemImage: "checklist")
                }

            AnalyticsTabRootView {
                selectedTab = .habits
            }
                .tag(MainTab.analytics)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }

            ProfileTabRootView {
                isPresentingOnboarding = true
            }
            .tag(MainTab.profile)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
        .background(HabitQuestDesignSystem.Palette.background(for: colorScheme))
        .fullScreenCover(isPresented: $isPresentingOnboarding) {
            OnboardingFlowView(mode: hasCompletedOnboarding ? .replay : .firstLaunch, onFinish: {
                completeOnboardingAndContinue()
            }, onChooseTemplate: { template in
                pendingHabitTemplate = template
                completeOnboardingAndContinue()
            })
        }
        .fullScreenCover(isPresented: $isPresentingPremiumTrialIntro) {
            PremiumTrialIntroView(
                subscriptionManager: environment.subscriptionManager,
                entitlementService: environment.premiumEntitlementService,
                onPrimaryAction: {
                    hasPresentedPremiumTrialIntro = true
                },
                onDecline: {
                    hasPresentedPremiumTrialIntro = true
                    isPresentingPremiumTrialIntro = false
                },
                onCompletedTrialOrPremium: {
                    isPresentingPremiumTrialIntro = false
                    selectedTab = .today
                }
            )
        }
        .fullScreenCover(item: $premiumFeatureGateDescriptor) { descriptor in
            PremiumFeatureGateView(
                entitlementService: environment.premiumEntitlementService,
                descriptor: descriptor,
                onDismiss: {
                    premiumPromotionRouter.clear()
                    premiumFeatureGateDescriptor = nil
                },
                onOpenPaywall: { metadata in
                    premiumPaywallSourceMetadata = metadata
                    premiumFeatureGateDescriptor = nil
                    isPresentingPremiumPaywall = true
                }
            ) {
                PremiumFeatureGatePreviewView(feature: descriptor.feature)
            }
        }
        .fullScreenCover(isPresented: $isPresentingPremiumPaywall, onDismiss: {
            premiumPaywallSourceMetadata = nil
        }) {
            PremiumPaywallView(
                subscriptionManager: environment.subscriptionManager,
                entitlementService: environment.premiumEntitlementService,
                sourceMetadata: premiumPaywallSourceMetadata
            )
        }
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarBackground(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .tabBar)
        .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        .onChange(of: premiumPromotionRouter.pendingGateDescriptor) { _, newValue in
            premiumFeatureGateDescriptor = newValue
        }
        .task {
            guard !didEvaluateFirstLaunch else { return }
            didEvaluateFirstLaunch = true

            if !hasCompletedOnboarding {
                isPresentingOnboarding = true
            } else {
                presentPremiumTrialIntroIfNeeded()
            }
        }
    }

    private func completeOnboardingAndContinue() {
        if !hasCompletedOnboarding {
            hasCompletedOnboarding = true
        }
        selectedTab = .habits
        isPresentingOnboarding = false
        presentPremiumTrialIntroIfNeeded()
    }

    private func presentPremiumTrialIntroIfNeeded() {
        guard hasCompletedOnboarding else { return }
        guard !hasPresentedPremiumTrialIntro else { return }
        guard environment.premiumEntitlementService.accessState.tier == .free else { return }
        guard environment.premiumEntitlementService.isEligibleForIntroOffer else { return }

        presentPremiumTrialIntro(force: false)
    }

    private func presentPremiumTrialIntro(force: Bool) {
        guard force || (!hasPresentedPremiumTrialIntro && hasCompletedOnboarding) else { return }
        guard environment.premiumEntitlementService.accessState.tier == .free else { return }
        guard force || environment.premiumEntitlementService.isEligibleForIntroOffer else { return }

        isPresentingPremiumTrialIntro = true
    }
}

enum MainTab {
    case today
    case habits
    case analytics
    case profile
}

private struct TodayTabRootView: View {
    let onOpenHabits: () -> Void
    @State private var path = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack(path: $path) {
            TodayFeatureView(onOpenHabits: onOpenHabits)
                .navigationTitle("Today")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }
}

enum HabitQuestOnboardingState {
    static let completedKey = "habitquest.onboarding.completed"
}

enum HabitQuestPremiumTrialIntroState {
    static let presentedKey = "habitquest.premium.trial-intro.presented"
}

private struct HabitsTabRootView: View {
    @Binding var pendingTemplate: HabitTemplate?
    @State private var path = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack(path: $path) {
            HabitsFeatureView(pendingTemplate: $pendingTemplate)
                .navigationTitle("Habits")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }
}

private struct AnalyticsTabRootView: View {
    let onOpenHabits: () -> Void
    @State private var path = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack(path: $path) {
            AnalyticsFeatureView(onOpenHabits: onOpenHabits)
                .navigationTitle("Analytics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }
}

private struct ProfileTabRootView: View {
    @State private var path = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.habitQuestEnvironment) private var environment

    let onReplayOnboarding: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            ProfileFeatureView(
                subscriptionManager: environment.subscriptionManager,
                onReplayOnboarding: onReplayOnboarding
            )
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }
}
