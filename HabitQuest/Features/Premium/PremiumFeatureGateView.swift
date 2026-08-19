import SwiftUI

struct PremiumFeatureGateView<PreviewContent: View>: View {
    @ObservedObject var entitlementService: PremiumEntitlementService

    let descriptor: PremiumFeatureGateDescriptor
    let onDismiss: () -> Void
    let onOpenPaywall: (PremiumPaywallSourceMetadata) -> Void
    let previewContent: () -> PreviewContent

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var didAutoDismiss = false

    init(
        entitlementService: PremiumEntitlementService,
        descriptor: PremiumFeatureGateDescriptor,
        onDismiss: @escaping () -> Void,
        onOpenPaywall: @escaping (PremiumPaywallSourceMetadata) -> Void,
        @ViewBuilder previewContent: @escaping () -> PreviewContent
    ) {
        self.entitlementService = entitlementService
        self.descriptor = descriptor
        self.onDismiss = onDismiss
        self.onOpenPaywall = onOpenPaywall
        self.previewContent = previewContent
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                    headerCard
                    previewCard
                    valueCard
                    sourceCard
                    actionCard
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
        }
        .task {
            if entitlementService.canAccess(descriptor.feature) {
                autoDismiss()
                return
            }

            environment.analyticsTracker.track(.premiumFeatureGateViewed(descriptor.analyticsContext))
        }
        .onChange(of: entitlementService.accessState) { _, newValue in
            if newValue.canAccess(descriptor.feature) {
                autoDismiss()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack {
                Spacer()

                Button {
                    dismissGate()
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
                .accessibilityLabel("Close Premium details")
                .accessibilityHint("Dismiss this Premium explanation and return to HabitQuest.")
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text(descriptor.feature.displayName)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

                Text(descriptor.headline)
                    .font(HabitQuestDesignSystem.Typography.title)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(descriptor.explanation)
                    .font(HabitQuestDesignSystem.Typography.body)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                statusPill(
                    title: entitlementService.isEligibleForIntroOffer ? "Trial available" : "Premium feature",
                    accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                )

                statusPill(
                    title: descriptor.paywallSourceMetadata.origin.displayName,
                    accent: HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme)
                )
            }
            .accessibilityElement(children: .combine)
        }
        .habitQuestSurface(.raised)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Preview")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            if let symbolName = descriptor.previewSymbolName {
                HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.4))
                            .frame(width: 54, height: 54)

                        Image(systemName: symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(descriptor.feature.displayName)
                                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                            Text("A preview of what this feature can do.")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        }
                    }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(HabitQuestDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                )
            }

            previewContent()
        }
        .habitQuestSurface(.raised)
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Why it matters")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(descriptor.explanation)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .habitQuestSurface(.raised)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Opened from")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            Text(descriptor.paywallSourceMetadata.displayLabel)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .habitQuestSurface(.raised)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Button {
                onOpenPaywall(descriptor.paywallSourceMetadata)
            } label: {
                Text(primaryActionTitle)
            }
            .habitQuestGlassButtonStyle(prominent: true)

            Button {
                dismissGate()
            } label: {
                Text("Not Now")
            }
            .habitQuestGlassButtonStyle()
        }
        .habitQuestSurface(.raised)
    }

    private var primaryActionTitle: String {
        entitlementService.isEligibleForIntroOffer ? "Try Premium Free" : "See Plans"
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

    private func dismissGate() {
        guard !didAutoDismiss else { return }
        didAutoDismiss = true
        onDismiss()
        dismiss()
    }

    private func autoDismiss() {
        guard !didAutoDismiss else { return }
        didAutoDismiss = true
        onDismiss()
        dismiss()
    }
}

struct PremiumFeatureGatePreviewView: View {
    let feature: PremiumFeature

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.25))
                        .frame(width: 52, height: 52)

                    Image(systemName: feature.gatePreviewSymbolName ?? "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.displayName)
                        .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text("A calm preview of the premium experience.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }
            }
        }
    }
}

struct PremiumFeaturePreviewCard<PreviewContent: View>: View {
    @ObservedObject var entitlementService: PremiumEntitlementService

    let descriptor: PremiumFeatureGateDescriptor
    let actionTitle: String
    let onOpenGate: (PremiumFeatureGateDescriptor) -> Void
    let previewContent: () -> PreviewContent

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if entitlementService.canAccess(descriptor.feature) {
            EmptyView()
        } else {
            Button {
                onOpenGate(descriptor)
            } label: {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                    HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
                        if let symbolName = descriptor.previewSymbolName {
                            ZStack {
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.22))
                                    .frame(width: 48, height: 48)

                                Image(systemName: symbolName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                                Text(descriptor.feature.displayName)
                                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                                PremiumPreviewBadge()
                            }

                            Text(descriptor.headline)
                                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    Text(descriptor.explanation)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    previewContent()

                    HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                        Text(actionTitle)
                            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .habitQuestSurface(.raised)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(descriptor.feature.displayName))
            .accessibilityValue(Text("Premium preview"))
            .accessibilityHint(Text("Preview the premium feature and see how HabitQuest upgrades it."))
        }
    }
}

struct PremiumPreviewBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Premium preview")
            .font(HabitQuestDesignSystem.Typography.footnote.weight(.semibold))
            .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                    )
            )
            .accessibilityHidden(true)
    }
}
