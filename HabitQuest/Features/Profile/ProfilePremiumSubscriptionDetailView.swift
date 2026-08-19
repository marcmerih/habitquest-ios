import SwiftUI

struct ProfilePremiumSubscriptionDetailView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager

    let onStartTrial: () -> Void
    let onOpenPremium: () -> Void

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var statusMessage: String?
    @State private var isPerformingAction = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                    heroCard
                    stateCard
                    productCard
                    timingCard
                    actionsCard
                    legalCard
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .habitQuestScreenBackground()
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("HabitQuest Premium")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(heroSubtitle)
                .font(HabitQuestDesignSystem.Typography.body)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if let statusMessage {
                Text(statusMessage)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .habitQuestSurface(.raised)
    }

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Current access")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Synced from your Apple account.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            stateRows
        }
        .habitQuestSurface(.raised)
    }

    private var stateRows: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            SubscriptionDetailRow(
                title: "Access state",
                value: accessStateTitle,
                accent: accessStateAccent
            )

            if let subscriptionStatus = subscriptionManager.accessState.subscriptionStatus {
                SubscriptionDetailRow(
                    title: "Subscription status",
                    value: subscriptionStatusTitle(subscriptionStatus),
                    accent: HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
                )
            }

            if subscriptionManager.accessState.subscriptionStatus?.isEligibleForIntroOffer == true {
                SubscriptionDetailRow(
                    title: "Trial eligibility",
                    value: "Eligible for the 7-day introductory offer",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                )
            }
        }
    }

    private var productCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Current plan")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Your current plan, when available.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            if let product = currentProduct {
                SubscriptionDetailRow(
                    title: product.displayName,
                    value: product.displayPrice,
                    accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                )

                if let period = product.subscriptionPeriodDescription {
                    SubscriptionDetailRow(
                        title: "Billing",
                        value: "Per \(period)",
                        accent: HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
                    )
                }

                if let offer = product.introductoryOfferDescription, subscriptionManager.accessState.isEligibleForIntroOffer {
                    SubscriptionDetailRow(
                        title: "Introductory offer",
                        value: offer,
                        accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                    )
                }
            } else {
                CalmEmptyStateCard(
                    icon: "sparkles",
                    title: "No product loaded yet",
                    message: "HabitQuest will load your plan details when they are available.",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Renewal and timing")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Renewal and expiration details appear here when available.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            if let expirationDate = subscriptionManager.accessState.metadata.subscriptionExpirationDate {
                SubscriptionDetailRow(
                    title: accessState.subscriptionStatus?.isActiveTrial == true ? "Trial ends" : "Renews",
                    value: Self.dateFormatter.string(from: expirationDate),
                    accent: HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
                )
            } else {
                SubscriptionDetailRow(
                    title: "Renewal",
                    value: renewalSummary,
                    accent: HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
                )
            }

            if let billingRetryState = subscriptionManager.accessState.metadata.billingRetryState {
                SubscriptionDetailRow(
                    title: "Billing retry",
                    value: billingRetryTitle(billingRetryState),
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                )
            }

            if let lastUpdatedAt = subscriptionManager.lastUpdatedAt {
                SubscriptionDetailRow(
                    title: "Last refreshed",
                    value: Self.dateFormatter.string(from: lastUpdatedAt),
                    accent: HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme)
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Button {
                performPrimaryAction()
            } label: {
                Text(primaryActionTitle)
            }
            .habitQuestGlassButtonStyle(prominent: true)
            .disabled(isPerformingAction)

            Button {
                Task { await restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            .habitQuestGlassButtonStyle()
            .disabled(isPerformingAction)

            Button {
                Task { await refreshStatus() }
            } label: {
                Label("Refresh subscription status", systemImage: "arrow.triangle.2.circlepath")
            }
            .habitQuestGlassButtonStyle()
            .disabled(isPerformingAction || subscriptionManager.isRefreshingAccess)

            if canManageSubscription {
                Button {
                    Task { await manageSubscription() }
                } label: {
                    Label("Manage Subscription", systemImage: "person.crop.circle.badge.gearshape")
                }
                .habitQuestGlassButtonStyle()
                .disabled(isPerformingAction)
            }
        }
        .habitQuestSurface(.raised)
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subscriptions renew automatically unless canceled in your Apple account settings.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("Subscription management happens in your Apple account. HabitQuest keeps this screen up to date.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .habitQuestSurface(.raised)
    }

    private var accessState: PremiumAccessState {
        subscriptionManager.accessState
    }

    private var currentProduct: SubscriptionProduct? {
        let productID = accessState.metadata.productInfo?.productIdentifier
        if let productID {
            return subscriptionManager.availableProducts.first(where: { $0.id == productID })
        }
        return subscriptionManager.availableProducts.first
    }

    private var accessStateTitle: String {
        switch accessState.tier {
        case .free:
            return "Free"
        case .trial:
            return "Premium Trial"
        case .premium:
            return "Premium"
        }
    }

    private var accessStateAccent: Color {
        switch accessState.tier {
        case .free:
            return HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme)
        case .trial:
            return HabitQuestDesignSystem.Palette.note(for: colorScheme)
        case .premium:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        }
    }

    private var primaryActionTitle: String {
        switch accessState.tier {
        case .free:
            return accessState.isEligibleForIntroOffer ? "Try Premium Free" : "Go Premium"
        case .trial, .premium:
            return "Manage Subscription"
        }
    }

    private var renewalSummary: String {
        switch accessState.tier {
        case .free:
            if accessState.isEligibleForIntroOffer {
                return "You can start the 7-day trial from here."
            }
            return "No active premium entitlement."
        case .trial:
            return "The trial renews into a paid subscription unless canceled."
        case .premium:
            return "The subscription renews automatically unless canceled."
        }
    }

    private var heroSubtitle: String {
        switch accessState.tier {
        case .free:
            if accessState.isEligibleForIntroOffer {
                return "Premium is available to try free for 7 days."
            }
            return "Premium can be unlocked whenever you're ready."
        case .trial:
            return "You’re currently on the 7-day Premium trial."
        case .premium:
            return "Premium is active on this device."
        }
    }

    private var canManageSubscription: Bool {
        accessState.tier == .trial || accessState.tier == .premium
    }

    private func billingRetryTitle(_ state: PremiumBillingRetryState) -> String {
        switch state {
        case .none:
            return "None"
        case .retrying:
            return "Retrying"
        case .gracePeriod:
            return "Grace period"
        }
    }

    private func subscriptionStatusTitle(_ status: PremiumSubscriptionStatus) -> String {
        switch status {
        case .free(let eligible, let hadPreviousEntitlement):
            if eligible {
                return "Eligible for the 7-day trial"
            }
            return hadPreviousEntitlement ? "Previously subscribed" : "No previous subscription"
        case .activeTrial:
            return "Active trial"
        case .activePaid:
            return "Active paid subscription"
        }
    }

    private func performPrimaryAction() {
        switch accessState.tier {
        case .free:
            if accessState.isEligibleForIntroOffer {
                onStartTrial()
            } else {
                onOpenPremium()
            }
        case .trial, .premium:
            Task { await manageSubscription() }
        }
    }

    private func restorePurchases() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        let result = await subscriptionManager.restorePurchases(analyticsContext: analyticsContext)
        if let message = result.userMessage {
            statusMessage = message
        }
    }

    private func refreshStatus() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        let result = await subscriptionManager.refreshSubscriptionStatus()
        if let message = result.userMessage {
            statusMessage = message
        }
    }

    private func manageSubscription() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        let result = await subscriptionManager.manageSubscription(analyticsContext: analyticsContext)
        if let message = result.userMessage {
            statusMessage = message
        }
    }

    private var analyticsContext: AnalyticsContextMetadata {
        AnalyticsContextMetadata(source: "premium_subscription_detail")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct SubscriptionDetailRow: View {
    let title: String
    let value: String
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

            Spacer(minLength: 0)

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(accent)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }
}
