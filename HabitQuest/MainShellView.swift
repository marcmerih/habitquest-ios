import SwiftUI

struct MainShellView: View {
    let environment: HabitQuestEnvironment

    @ObservedObject private var premiumPromotionRouter: PremiumPromotionRouter
    @ObservedObject private var streakFreezeService: StreakFreezeService
    @State private var selectedTab: MainTab = .today
    @State private var isPresentingOnboarding = false
    @State private var isPresentingPremiumTrialIntro = false
    @State private var isPresentingPremiumPaywall = false
    @State private var streakFreezeOpportunity: StreakFreezeOpportunity?
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var didEvaluateFirstLaunch = false
    @State private var didPresentStreakFreezeModalThisSession = false
    @State private var pendingHabitTemplate: HabitTemplate?
    @AppStorage(HabitQuestOnboardingState.completedKey) private var hasCompletedOnboarding = false
    @AppStorage(HabitQuestPremiumTrialIntroState.presentedKey) private var hasPresentedPremiumTrialIntro = false
    @Environment(\.colorScheme) private var colorScheme

    init(environment: HabitQuestEnvironment) {
        self.environment = environment
        self._premiumPromotionRouter = ObservedObject(wrappedValue: environment.premiumPromotionRouter)
        self._streakFreezeService = ObservedObject(wrappedValue: environment.streakFreezeService)
        self._premiumFeatureGateDescriptor = State(initialValue: environment.premiumPromotionRouter.pendingGateDescriptor)
        self._streakFreezeOpportunity = State(initialValue: environment.streakFreezeService.activeOpportunity)
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
        .fullScreenCover(item: $streakFreezeOpportunity) { opportunity in
            StreakFreezeModalView(
                opportunity: opportunity,
                currentXP: currentXP,
                onSaveStreak: {
                    switch streakFreezeService.purchaseFreeze() {
                    case .saved:
                        streakFreezeOpportunity = nil
                        didPresentStreakFreezeModalThisSession = true
                    case .noPendingOpportunity, .insufficientXP(_, _):
                        break
                    }
                },
                onDecline: {
                    streakFreezeService.dismissOpportunity()
                    streakFreezeOpportunity = nil
                    didPresentStreakFreezeModalThisSession = true
                }
            )
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
        .onChange(of: streakFreezeService.state) { _, newValue in
            guard !didPresentStreakFreezeModalThisSession else { return }
            streakFreezeOpportunity = newValue.pendingOpportunity
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

    private var currentXP: Int {
        (try? environment.progressionStore.loadProgression().lifetimeXP) ?? 0
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

struct StreakFreezeModalView: View {
    let opportunity: StreakFreezeOpportunity
    let currentXP: Int
    let onSaveStreak: () -> Void
    let onDecline: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var hasEnoughXP: Bool {
        currentXP >= opportunity.costXP
    }

    private var shortfall: Int {
        max(opportunity.costXP - currentXP, 0)
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                HStack {
                    Spacer(minLength: 0)
                    Button("Close") {
                        onDecline()
                    }
                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Spacer(minLength: 0)

                VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    Circle()
                        .fill(HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.14))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                        )

                    VStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                        Text("Save your streak")
                            .font(HabitQuestDesignSystem.Typography.title2)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("You have 24 hours to protect this run.")
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                        freezeStatRow(
                            label: "Current streak",
                            value: "\(opportunity.baselineStreak) days"
                        )
                        freezeStatRow(
                            label: "Freeze cost",
                            value: "\(opportunity.costXP) XP"
                        )
                        freezeStatRow(
                            label: "Time left",
                            value: deadlineText
                        )
                    }

                    Text("The cost scales with your active difficult habits so it stays fair.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onSaveStreak()
                    } label: {
                        if hasEnoughXP {
                            Text("Use \(opportunity.costXP) XP")
                        } else {
                            Text("Need \(shortfall) more XP")
                        }
                    }
                    .buttonStyle(HabitQuestButtonStyle(role: .primary))
                    .disabled(!hasEnoughXP)

                    Button("Not now") {
                        onDecline()
                    }
                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .padding(.top, HabitQuestDesignSystem.Spacing.xs)
                }
                .frame(maxWidth: 440)
                .padding(HabitQuestDesignSystem.Spacing.lg)
                .habitQuestSurface(.raised)

                Spacer(minLength: 0)
            }
            .padding(HabitQuestDesignSystem.Spacing.pageHorizontal)
            .padding(.vertical, HabitQuestDesignSystem.Spacing.lg)
        }
    }

    private func freezeStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            Spacer(minLength: 0)
            Text(value)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
        }
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
        .padding(.vertical, HabitQuestDesignSystem.Spacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme).opacity(0.7))
        )
    }

    private var deadlineText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: opportunity.deadline)
    }
}
