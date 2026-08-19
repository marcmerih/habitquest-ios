import SwiftUI

struct PremiumPaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var entitlementService: PremiumEntitlementService
    let sourceMetadata: PremiumPaywallSourceMetadata?

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var isPresentingLegalDocument: PremiumLegalDocument?
    @State private var statusMessage: String?
    @State private var isPerformingAction = false

    init(
        subscriptionManager: SubscriptionManager,
        entitlementService: PremiumEntitlementService,
        sourceMetadata: PremiumPaywallSourceMetadata? = nil
    ) {
        self.subscriptionManager = subscriptionManager
        self.entitlementService = entitlementService
        self.sourceMetadata = sourceMetadata
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                    headerCard
                    valueCard
                    plansCard
                    callToActionCard
                    footerCard
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
        }
        .task {
            environment.analyticsTracker.track(.premiumPaywallViewed(analyticsContext))
            await bootstrap()
        }
        .onChange(of: subscriptionManager.availableProducts.map(\.id)) { _, _ in
            selectDefaultProductIfNeeded()
        }
        .onChange(of: subscriptionManager.accessState) { _, newValue in
            guard isPerformingAction, newValue.isPremiumOrTrial else { return }
            isPerformingAction = false
            dismiss()
        }
        .sheet(item: $isPresentingLegalDocument) { document in
            PremiumLegalDocumentView(document: document)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack {
                Spacer()

                Button {
                    dismiss()
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
                .accessibilityLabel("Close paywall")
                .accessibilityHint("Dismiss the subscription screen and return to HabitQuest.")
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("HabitQuest Premium")
                    .font(HabitQuestDesignSystem.Typography.title)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text("HabitQuest already works beautifully. Premium makes it more powerful and personal.")
                    .font(HabitQuestDesignSystem.Typography.body)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if let sourceMetadata {
                    Text(sourceMetadata.displayLabel)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                statusPill(
                    title: entitlementService.isEligibleForIntroOffer ? "7-day trial available" : "No trial available",
                    accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                )

                if entitlementService.subscriptionStatus?.isActiveTrial == true {
                    statusPill(
                        title: "Trial active",
                        accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                    )
                } else if entitlementService.subscriptionStatus?.isActivePaid == true {
                    statusPill(
                        title: "Premium active",
                        accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
                    )
                }
            }
            .accessibilityElement(children: .combine)
        }
        .habitQuestSurface(.raised)
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("What Premium gives you")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("More depth, more flexibility, and more of the calm HabitQuest feeling.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(PremiumPaywallFeatureHighlight.allCases) { highlight in
                    PremiumPaywallFeatureRow(highlight: highlight)
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var plansCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Choose a plan")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Annual is recommended, but Monthly stays easy to choose.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            if subscriptionManager.availableProducts.isEmpty {
                loadingPlansPlaceholder
            } else {
                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                        PremiumPaywallPlanCard(
                            product: product,
                            isSelected: selectedProductID == product.id,
                            isRecommended: product.id == SubscriptionCatalog.annualProductID,
                            hasTrial: entitlementService.isEligibleForIntroOffer
                        ) {
                            selectedProductID = product.id
                        }
                    }
                }
            }

            if let message = statusMessage {
                Text(message)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .habitQuestSurface(.raised)
    }

    private var callToActionCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Button {
                Task { await primaryAction() }
            } label: {
                Text(primaryActionTitle)
            }
            .habitQuestGlassButtonStyle(prominent: true)
            .disabled(isPerformingAction || (!entitlementService.accessState.isPremiumOrTrial && selectedProduct == nil))

            if let selectedProduct {
                Text(primaryDisclosure(for: selectedProduct))
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .habitQuestSurface(.raised)
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                Button {
                    Task { await restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                .disabled(isPerformingAction)

                if entitlementService.accessState.isPremiumOrTrial {
                    Spacer(minLength: 0)

                    Button {
                        Task { await manageSubscription() }
                    } label: {
                        Label("Manage Subscription", systemImage: "person.crop.circle.badge.gearshape")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .disabled(isPerformingAction)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                Button {
                    isPresentingLegalDocument = .termsOfUse
                } label: {
                    Text("Terms of Use")
                }
                .buttonStyle(.plain)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                Text("•")
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

                Button {
                    isPresentingLegalDocument = .privacyPolicy
                } label: {
                    Text("Privacy Policy")
                }
                .buttonStyle(.plain)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }
            .font(HabitQuestDesignSystem.Typography.caption)

            Text("Subscriptions renew automatically unless canceled in App Store settings. Payment is charged to your Apple account.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .habitQuestSurface(.raised)
    }

    private var loadingPlansPlaceholder: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            ProgressView()
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            Text("Loading subscription options...")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, HabitQuestDesignSystem.Spacing.sm)
    }

    private var selectedProduct: SubscriptionProduct? {
        guard let selectedProductID else { return nil }
        return subscriptionManager.availableProducts.first(where: { $0.id == selectedProductID })
    }

    private var analyticsContext: AnalyticsContextMetadata {
        sourceMetadata?.analyticsContext ?? AnalyticsContextMetadata(source: "premium_paywall")
    }

    private var primaryActionTitle: String {
        if entitlementService.subscriptionStatus?.isActiveTrial == true || entitlementService.subscriptionStatus?.isActivePaid == true {
            return "Continue"
        }

        guard entitlementService.isEligibleForIntroOffer else {
            return "Go Premium"
        }

        return "Try Premium Free"
    }

    private func primaryDisclosure(for product: SubscriptionProduct) -> String {
        var parts: [String] = []

        if entitlementService.isEligibleForIntroOffer, let trial = product.introductoryOfferDescription {
            parts.append(trial)
        }

        if let period = product.subscriptionPeriodDescription {
            parts.append("Renews at \(product.displayPrice) per \(period)")
        } else {
            parts.append("Renews at \(product.displayPrice)")
        }

        return parts.joined(separator: " · ")
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

    private func bootstrap() async {
        await subscriptionManager.startIfNeeded()

        if subscriptionManager.availableProducts.isEmpty {
            await subscriptionManager.refreshProducts()
        }

        await subscriptionManager.refreshAccessState()
        selectDefaultProductIfNeeded()
    }

    private func selectDefaultProductIfNeeded() {
        guard selectedProduct == nil || !subscriptionManager.availableProducts.contains(where: { $0.id == selectedProductID }) else {
            return
        }

        if let annual = subscriptionManager.availableProducts.first(where: { $0.id == SubscriptionCatalog.annualProductID }) {
            selectedProductID = annual.id
        } else {
            selectedProductID = subscriptionManager.availableProducts.first?.id
        }
    }

    private func primaryAction() async {
        if entitlementService.accessState.isPremiumOrTrial {
            dismiss()
            return
        }

        await subscribe()
    }

    private func subscribe() async {
        guard let selectedProduct else {
            statusMessage = "Loading subscription options..."
            return
        }

        isPerformingAction = true
        statusMessage = nil

        await subscriptionManager.purchase(productID: selectedProduct.id, analyticsContext: analyticsContext)

        if subscriptionManager.accessState.isPremiumOrTrial {
            dismiss()
        } else if let error = subscriptionManager.lastError {
            statusMessage = error.errorDescription ?? "Something prevented the subscription from completing."
        }

        isPerformingAction = false
    }

    private func restorePurchases() async {
        isPerformingAction = true
        statusMessage = nil

        let result = await subscriptionManager.restorePurchases(analyticsContext: analyticsContext)

        if subscriptionManager.accessState.isPremiumOrTrial {
            dismiss()
        } else if let message = result.userMessage {
            statusMessage = message
        }

        isPerformingAction = false
    }

    private func manageSubscription() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        statusMessage = nil

        let result = await subscriptionManager.manageSubscription(analyticsContext: analyticsContext)
        if let message = result.userMessage {
            statusMessage = message
        }

        isPerformingAction = false
    }
}

private enum PremiumPaywallFeatureHighlight: String, CaseIterable, Identifiable {
    case advancedDailyRoutines
    case customDayOrganization
    case smarterReminders
    case advancedScheduling
    case deepAnalytics
    case premiumPersonalization
    case advancedWidgets
    case futureInsights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .advancedDailyRoutines:
            return "Advanced Daily Routines"
        case .customDayOrganization:
            return "Custom day organization"
        case .smarterReminders:
            return "Smarter reminders"
        case .advancedScheduling:
            return "Advanced scheduling"
        case .deepAnalytics:
            return "Deep Analytics"
        case .premiumPersonalization:
            return "Premium personalization"
        case .advancedWidgets:
            return "Advanced widgets"
        case .futureInsights:
            return "Future Habit Insights"
        }
    }

    var subtitle: String {
        switch self {
        case .advancedDailyRoutines:
            return "Build richer, more intentional rhythms."
        case .customDayOrganization:
            return "Shape the day around how you actually live."
        case .smarterReminders:
            return "More flexible reminders, tuned to your flow."
        case .advancedScheduling:
            return "Handle more complex recurrence patterns."
        case .deepAnalytics:
            return "See patterns with more depth and context."
        case .premiumPersonalization:
            return "Bring more of your own taste into the app."
        case .advancedWidgets:
            return "Keep HabitQuest close at a glance."
        case .futureInsights:
            return "Unlock new premium intelligence as it arrives."
        }
    }

    var symbol: String {
        switch self {
        case .advancedDailyRoutines:
            return "calendar.badge.clock"
        case .customDayOrganization:
            return "square.grid.2x2"
        case .smarterReminders:
            return "bell.badge"
        case .advancedScheduling:
            return "clock.arrow.circlepath"
        case .deepAnalytics:
            return "chart.bar.xaxis"
        case .premiumPersonalization:
            return "paintbrush.pointed"
        case .advancedWidgets:
            return "rectangle.grid.2x2.fill"
        case .futureInsights:
            return "sparkles"
        }
    }
}

private struct PremiumPaywallFeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let highlight: PremiumPaywallFeatureHighlight

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.45))
                    .frame(width: 34, height: 34)

                Image(systemName: highlight.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(highlight.title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text(highlight.subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct PremiumPaywallPlanCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let product: SubscriptionProduct
    let isSelected: Bool
    let isRecommended: Bool
    let hasTrial: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayName)
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        Text(product.subscriptionPeriodDescription ?? "Subscription")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }

                    Spacer(minLength: 0)

                    if isRecommended {
                        Text("Recommended")
                            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                            .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.25))
                        )
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                            .accessibilityHidden(true)
                    }
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayPrice)
                            .font(HabitQuestDesignSystem.Typography.title2)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        if let period = product.subscriptionPeriodDescription {
                            Text("per \(period)")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(product.displayPrice)
                            .font(HabitQuestDesignSystem.Typography.title2)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        if let period = product.subscriptionPeriodDescription {
                            Text("per \(period)")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        }
                    }
                }

                if hasTrial, let trialDescription = product.introductoryOfferDescription {
                    Text(trialDescription)
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.note(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HabitQuestDesignSystem.Spacing.md)
            .background(backgroundShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Double tap to choose this subscription plan.")
        .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
    }

    private var accessibilityLabel: Text {
        var description = "\(product.displayName), \(product.displayPrice)"
        if let period = product.subscriptionPeriodDescription {
            description += ", billed per \(period)"
        }
        if isRecommended {
            description += ", recommended"
        }
        if isSelected {
            description += ", selected"
        }
        return Text(description)
    }

    private var accessibilityValue: Text {
        var details: [String] = []
        details.append(isSelected ? "Selected" : "Not selected")
        if isRecommended {
            details.append("Recommended")
        }
        if hasTrial, let trialDescription = product.introductoryOfferDescription {
            details.append(trialDescription)
        }
        return Text(details.joined(separator: ", "))
    }

    private var backgroundShape: some View {
        let shape = RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)

        return shape
            .fill(
                isSelected
                    ? HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.22)
                    : HabitQuestDesignSystem.Palette.surface(for: colorScheme)
            )
            .overlay(
                shape.stroke(
                    isSelected ? HabitQuestDesignSystem.Palette.accent(for: colorScheme) : HabitQuestDesignSystem.Palette.border(for: colorScheme),
                    lineWidth: isSelected ? 1.4 : 1
                )
        )
    }
}

#if DEBUG
private struct PremiumPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        let entitlementService = PremiumEntitlementService(accessState: .init(tier: .free))
        let subscriptionManager = SubscriptionManager(
            client: PreviewStoreKitSubscriptionClient(),
            entitlementService: entitlementService
        )

        return PremiumPaywallView(
            subscriptionManager: subscriptionManager,
            entitlementService: entitlementService
        )
    }
}
#endif

private enum PremiumLegalDocument: String, Identifiable {
    case termsOfUse
    case privacyPolicy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .termsOfUse:
            return "Terms of Use"
        case .privacyPolicy:
            return "Privacy Policy"
        }
    }

    var body: String {
        switch self {
        case .termsOfUse:
            return """
            HabitQuest Premium is purchased through Apple's In-App Purchase system. Apple manages billing, renewal, and cancellation.

            Premium subscriptions renew automatically unless canceled in your Apple account settings before the end of the current billing period.

            Premium purchases are handled through the App Store.
            """
        case .privacyPolicy:
            return """
            HabitQuest keeps your habits, completion history, and settings on this device unless you choose to export them.

            HabitQuest uses Apple to manage subscriptions. You do not need a cloud account to use the app.

            Future privacy choices or optional sync features will be introduced explicitly if added later.
            """
        }
    }
}

private final class PreviewStoreKitSubscriptionClient: SubscriptionStoreKitClient {
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

private struct PremiumLegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let document: PremiumLegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                    Text(document.body)
                        .font(HabitQuestDesignSystem.Typography.body)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(HabitQuestDesignSystem.Spacing.pageHorizontal)
            }
            .navigationTitle(document.title)
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
}
