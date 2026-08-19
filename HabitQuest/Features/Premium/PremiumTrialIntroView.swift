import SwiftUI

struct PremiumTrialIntroView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var entitlementService: PremiumEntitlementService

    let onPrimaryAction: () -> Void
    let onDecline: () -> Void
    let onCompletedTrialOrPremium: () -> Void

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPresentingPaywall = false
    @State private var didStartPremiumFlow = false

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                    heroCard
                    benefitsCard
                    actionCard
                    footerCard
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
        }
        .task {
            environment.analyticsTracker.track(.premiumTrialOffered(AnalyticsContextMetadata(source: "premium_trial_intro")))
            await subscriptionManager.startIfNeeded()
        }
        .fullScreenCover(isPresented: $isPresentingPaywall) {
            PremiumPaywallView(
                subscriptionManager: subscriptionManager,
                entitlementService: entitlementService
            )
        }
        .onChange(of: subscriptionManager.accessState) { _, newValue in
            guard didStartPremiumFlow, newValue.isPremiumOrTrial else { return }
            onCompletedTrialOrPremium()
            dismiss()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack {
                Spacer()

                Button {
                    decline()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                .overlay(
                                    Circle()
                                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not now")
                .accessibilityHint("Dismiss this Premium introduction and continue into HabitQuest Free.")
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("Try HabitQuest Premium free for 7 days")
                    .font(HabitQuestDesignSystem.Typography.title)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Premium adds more room to shape the day around your real life, while keeping the app calm and easy to return to.")
                    .font(HabitQuestDesignSystem.Typography.body)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                statusPill(
                    title: "7-day trial",
                    accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                )

                statusPill(
                    title: "Optional",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("What Premium unlocks")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("A few meaningful ways HabitQuest becomes more personal.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(PremiumTrialBenefit.allCases) { benefit in
                    PremiumTrialBenefitRow(benefit: benefit)
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Button {
                startPremiumFlow()
            } label: {
                Text("Try Premium Free")
            }
            .habitQuestGlassButtonStyle(prominent: true)

            Button {
                decline()
            } label: {
                Text("Not Now")
            }
            .habitQuestGlassButtonStyle()
        }
        .habitQuestSurface(.raised)
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text("If you start the trial, Premium turns on right away through the App Store.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("You can also come back later from Profile while the trial offer is still available.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .habitQuestSurface(.raised)
    }

    private func statusPill(title: String, accent: Color) -> some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
            )
    }

    private func startPremiumFlow() {
        onPrimaryAction()
        didStartPremiumFlow = true
        isPresentingPaywall = true
    }

    private func decline() {
        environment.analyticsTracker.track(.premiumTrialDeclined(AnalyticsContextMetadata(source: "premium_trial_intro")))
        onDecline()
        dismiss()
    }
}

private enum PremiumTrialBenefit: String, CaseIterable, Identifiable {
    case morningAfternoonEvening
    case smarterReminders
    case deeperAnalytics
    case personalization
    case advancedScheduling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningAfternoonEvening:
            return "Organize habits into Morning, Afternoon, and Evening routines"
        case .smarterReminders:
            return "Configure smarter reminders"
        case .deeperAnalytics:
            return "Unlock deeper Analytics"
        case .personalization:
            return "Personalize HabitQuest"
        case .advancedScheduling:
            return "Use more advanced scheduling"
        }
    }

    var subtitle: String {
        switch self {
        case .morningAfternoonEvening:
            return "Shape the day around how it naturally unfolds."
        case .smarterReminders:
            return "Bring reminders closer to your real rhythm."
        case .deeperAnalytics:
            return "See patterns with more context and reflection."
        case .personalization:
            return "Make the app feel more like your own space."
        case .advancedScheduling:
            return "Support more nuanced recurrence and timing rules."
        }
    }

    var symbol: String {
        switch self {
        case .morningAfternoonEvening:
            return "sun.horizon"
        case .smarterReminders:
            return "bell.badge"
        case .deeperAnalytics:
            return "chart.bar.xaxis"
        case .personalization:
            return "paintbrush.pointed"
        case .advancedScheduling:
            return "calendar.badge.plus"
        }
    }
}

private struct PremiumTrialBenefitRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let benefit: PremiumTrialBenefit

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.45))
                    .frame(width: 34, height: 34)

                Image(systemName: benefit.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(benefit.title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(benefit.subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
private struct PremiumTrialIntroView_Previews: PreviewProvider {
    static var previews: some View {
        let entitlementService = PremiumEntitlementService(accessState: .free)
        return PremiumTrialIntroView(
            subscriptionManager: SubscriptionManager(
                client: PremiumTrialIntroPreviewStoreKitClient(),
                entitlementService: entitlementService
            ),
            entitlementService: entitlementService,
            onPrimaryAction: {},
            onDecline: {},
            onCompletedTrialOrPremium: {}
        )
    }
}
#endif

private final class PremiumTrialIntroPreviewStoreKitClient: SubscriptionStoreKitClient {
    func loadProducts() async throws -> [SubscriptionProduct] {
        [
            SubscriptionProduct(
                id: SubscriptionCatalog.monthlyProductID,
                displayName: "HabitQuest Premium Monthly",
                displayPrice: "$4.99",
                subscriptionPeriodDescription: "month",
                introductoryOfferDescription: "7-day free trial",
                subscriptionGroupDisplayName: "HabitQuest Premium",
                storefrontName: "United States",
                isEligibleForIntroOffer: true
            ),
            SubscriptionProduct(
                id: SubscriptionCatalog.annualProductID,
                displayName: "HabitQuest Premium Annual",
                displayPrice: "$39.99",
                subscriptionPeriodDescription: "year",
                introductoryOfferDescription: "7-day free trial",
                subscriptionGroupDisplayName: "HabitQuest Premium",
                storefrontName: "United States",
                isEligibleForIntroOffer: true
            )
        ]
    }

    func refreshAccessState() async throws -> PremiumAccessState {
        .free
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        .cancelled
    }

    func restorePurchases() async throws { }

    func observeTransactionUpdates(onUpdate: @escaping @Sendable () async -> Void) -> SubscriptionUpdateObservation {
        SubscriptionUpdateObservation(cancellation: { })
    }
}
