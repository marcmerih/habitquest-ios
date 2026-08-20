import SwiftUI
import UIKit
import UserNotifications
import PhotosUI

struct ProfileFeatureView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var personalizationStore = HabitQuestPersonalizationStore.shared
    let onReplayOnboarding: () -> Void

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage(HabitQuestProfileKeys.displayName) private var displayName = ""
    @AppStorage(HabitQuestProfileKeys.aliasName) private var profileAlias = ""
    @AppStorage(HabitQuestProfileKeys.avatarSymbolName) private var profileAvatarSymbolName = ""
    @AppStorage(HabitQuestProfileKeys.avatarImageData) private var profileAvatarImageData = Data()
    @AppStorage(HabitQuestAppearanceMode.storageKey) private var appearanceModeRaw = HabitQuestAppearanceMode.system.rawValue
    @AppStorage(HabitQuestOnboardingState.completedKey) private var hasCompletedOnboarding = false

    @State private var habits: [Habit] = []
    @State private var progressionSummary = HabitProgressionCalculator().summary(from: .default)
    @State private var achievements: [HabitAchievement] = []
    @State private var statistics = ProfileStatisticsSnapshot()
    @State private var notificationPreferences = HabitQuestNotificationPreferences.default
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportItem: ProfileExportItem?
    @State private var statusMessage: String?
    @State private var toastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var isPresentingDeleteConfirmation = false
    @State private var isPresentingPremiumDetail = false
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var isPresentingPremiumTrialIntro = false
    @State private var isPresentingPremiumPaywall = false
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var isPerformingDataAction = false
    @State private var isPresentingProfileEditor = false
    @State private var draftDisplayName = ""
    @State private var draftAvatarSymbolName = ""
    @State private var draftAvatarImageData = Data()
    @State private var isPresentingAchievementsSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            HabitQuestScreenBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                    if let statusMessage {
                        statusBanner(message: statusMessage)
                    }

                    premiumCard
                    identityCard
                    progressionCard
                    statisticsCard
                    achievementsCard
                    settingsCard
                    footerFinePrint
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }

            if let toastMessage {
                ProfileToast(message: toastMessage)
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .sheet(item: $exportItem) { item in
            ActivityView(activityItems: [item.url])
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingAchievementsSheet) {
            AchievementsDetailView(
                achievements: achievementRows,
                onClose: {
                    isPresentingAchievementsSheet = false
                }
            )
        }
        .sheet(isPresented: $isPresentingPremiumDetail) {
            ProfilePremiumSubscriptionDetailView(
                subscriptionManager: subscriptionManager,
                onStartTrial: {
                    isPresentingPremiumTrialIntro = true
                },
                onOpenPremium: {
                    premiumFeatureGateDescriptor = PremiumFeature.advancedCustomization.gateDescriptor(
                        origin: .profile,
                        entryPoint: "Profile Premium card"
                    )
                }
            )
        }
        .fullScreenCover(item: $premiumFeatureGateDescriptor) { descriptor in
            PremiumFeatureGateView(
                entitlementService: environment.premiumEntitlementService,
                descriptor: descriptor,
                onDismiss: {
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
        .fullScreenCover(isPresented: $isPresentingPremiumTrialIntro) {
            PremiumTrialIntroView(
                subscriptionManager: subscriptionManager,
                entitlementService: environment.premiumEntitlementService,
                onPrimaryAction: {},
                onDecline: {
                    isPresentingPremiumTrialIntro = false
                },
                onCompletedTrialOrPremium: {
                    isPresentingPremiumTrialIntro = false
                }
            )
        }
        .fullScreenCover(isPresented: $isPresentingPremiumPaywall, onDismiss: {
            premiumPaywallSourceMetadata = nil
        }) {
            PremiumPaywallView(
                subscriptionManager: subscriptionManager,
                entitlementService: environment.premiumEntitlementService,
                sourceMetadata: premiumPaywallSourceMetadata
            )
        }
        .confirmationDialog(
            "Delete local data?",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete local data", role: .destructive) {
                Task { await deleteLocalData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes habits, history, achievements, reminders, and local preferences from this device.")
        }
        .sheet(isPresented: $isPresentingProfileEditor) {
            ProfileIdentityEditorView(
                displayName: $draftDisplayName,
                avatarSymbolName: $draftAvatarSymbolName,
                avatarImageData: $draftAvatarImageData,
                onSave: saveProfileIdentity,
                onCancel: {
                    isPresentingProfileEditor = false
                }
            )
        }
        .task {
            ensureProfileIdentityDefaults()
            await loadProfileContent()
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                Button {
                    beginEditingProfileIdentity()
                } label: {
                    avatarBadgeView
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit profile image and name")
                .accessibilityHint("Open profile editing.")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile")
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

                    HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.xs) {
                        Text(profileDisplayName)
                            .font(HabitQuestDesignSystem.Typography.title2)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Button {
                            beginEditingProfileIdentity()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit profile name")
                    }

                    Text("Used for gentle greetings like “Good morning, \(profileDisplayName)” in Today.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Spacer(minLength: 0)
            }

            Text("Your profile stays on this device. No account is required.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                MetricTile(
                    title: "Level",
                    value: "\(progressionSummary.currentLevel)",
                    accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                )

                MetricTile(
                    title: "XP",
                    value: "\(progressionSummary.lifetimeXP)",
                    accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Progress")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("XP stays separate from streaks, Momentum, and milestones.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            ProgressView(value: progressionSummary.progressToNextLevel)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                MetricPair(
                    title: "To next level",
                    value: "\(progressionSummary.xpIntoCurrentLevel)/\(progressionSummary.xpRequiredForNextLevel)"
                )

                MetricPair(
                    title: "Current level",
                    value: "\(progressionSummary.currentLevel)"
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Personal statistics")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("A quiet snapshot of how the local habit system is going.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: HabitQuestDesignSystem.Spacing.sm),
                    GridItem(.flexible(), spacing: HabitQuestDesignSystem.Spacing.sm)
                ],
                spacing: HabitQuestDesignSystem.Spacing.sm
            ) {
                MetricTile(title: "Active habits", value: "\(statistics.activeHabits)", accent: HabitQuestDesignSystem.Palette.note(for: colorScheme))
                MetricTile(title: "Archived", value: "\(statistics.archivedHabits)", accent: HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                MetricTile(title: "Completions", value: "\(statistics.totalCompletions)", accent: HabitQuestDesignSystem.Palette.success(for: colorScheme))
                MetricTile(title: "Today streak", value: "\(statistics.currentDailyStreak)", accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                MetricPair(
                    title: "Longest streak",
                    value: "\(statistics.longestDailyStreak)"
                )

                MetricPair(
                    title: "Momentum",
                    value: "\(Int(statistics.currentMomentum.rounded()))"
                )
            }

            if let completionRate = statistics.completionRate {
                Text("30-day completion rate: \(completionRate.formatted(.number.precision(.fractionLength(0))))%")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }
        }
        .habitQuestSurface(.raised)
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Achievements")
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text("Quiet acknowledgements for real progress.")
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Spacer(minLength: 0)

                Button("See all") {
                    isPresentingAchievementsSheet = true
                }
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }

            if achievementRows.isEmpty {
                CalmEmptyStateCard(
                    icon: "medal",
                    title: "No achievements yet",
                    message: "Your first milestones will appear here as the system starts collecting history.",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                    supportingText: "Quiet acknowledgements will appear once the app has a little more progress to reflect on."
                )
            } else {
                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(Array(achievementRows.prefix(6))) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Calm controls for the local app experience.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                settingsSection(
                    title: "Notifications",
                    subtitle: "Local reminders and quiet hours."
                ) {
                    if notificationAuthorizationStatus == .denied {
                        CalmEmptyStateCard(
                            icon: "bell.slash",
                            title: "Notifications are off in iOS",
                            message: "HabitQuest can keep your reminder preferences locally, but iOS is currently blocking delivery on this device.",
                            accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                            supportingText: "Open Settings if you want to allow reminders again later.",
                            primaryActionTitle: "Open Settings",
                            primaryAction: openAppSettings
                        )
                    } else {
                        Toggle("Enable reminders", isOn: remindersEnabledBinding)
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)

                        Toggle("Promotional suggestions", isOn: promotionalNotificationsEnabledBinding)
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)

                        VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                            DatePicker(
                                "Quiet hours start",
                                selection: quietHoursStartBinding,
                                displayedComponents: .hourAndMinute
                            )
                            DatePicker(
                                "Quiet hours end",
                                selection: quietHoursEndBinding,
                                displayedComponents: .hourAndMinute
                            )
                        }

                        Text("\(notificationPreferences.disabledHabitIDs.count) habits are muted individually.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    }
                }

                Divider().overlay(HabitQuestDesignSystem.Palette.border(for: colorScheme))

                settingsSection(
                    title: "Appearance",
                    subtitle: "Follow the system or use a fixed theme."
                ) {
                    Picker("Appearance", selection: appearanceModeBinding) {
                        ForEach(HabitQuestAppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider().overlay(HabitQuestDesignSystem.Palette.border(for: colorScheme))

                settingsSection(
                    title: "Personalization",
                    subtitle: personalizationSubtitle
                ) {
                    if personalizationStore.canUsePremiumPersonalization {
                        VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                            premiumSelectionMenu(
                                title: "Theme",
                                subtitle: "Warm visual variants for the whole app.",
                                selection: themeVariantBinding,
                                options: HabitQuestPremiumThemeVariant.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: iconName(for: $0))
                                }
                            )

                            premiumSelectionMenu(
                                title: "Accent palette",
                                subtitle: "Small color shifts for a different feel.",
                                selection: accentPaletteBinding,
                                options: HabitQuestPremiumAccentPalette.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: accentIconName(for: $0))
                                }
                            )

                            premiumSelectionMenu(
                                title: "Card appearance",
                                subtitle: "Adjust the glass and framing of habit cards.",
                                selection: cardAppearanceBinding,
                                options: HabitQuestPremiumCardAppearance.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: cardIconName(for: $0))
                                }
                            )

                            premiumSelectionMenu(
                                title: "Completion effects",
                                subtitle: "Choose how completed habits settle.",
                                selection: completionEffectBinding,
                                options: HabitQuestPremiumCompletionEffectStyle.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: completionIconName(for: $0))
                                }
                            )

                            premiumSelectionMenu(
                                title: "Haptic style",
                                subtitle: "Keep feedback subtle or make it more expressive.",
                                selection: hapticStyleBinding,
                                options: HabitQuestPremiumHapticStyle.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: hapticIconName(for: $0))
                                }
                            )

                            premiumSelectionMenu(
                                title: "Sound style",
                                subtitle: "Silent, soft, or lightly glassy.",
                                selection: soundStyleBinding,
                                options: HabitQuestPremiumSoundStyle.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: soundIconName(for: $0))
                                }
                            )

                            premiumSelectionMenu(
                                title: "Progression cosmetics",
                                subtitle: "Tone the progression language up or down.",
                                selection: progressionCosmeticBinding,
                                options: HabitQuestProgressionCosmeticStyle.allCases.map {
                                    .init(value: $0, label: $0.displayName, symbolName: progressionIconName(for: $0))
                                }
                            )

                            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                                Text("App icon")
                                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                                Text("Choose an alternate icon and apply it when supported on this device.")
                                    .font(HabitQuestDesignSystem.Typography.caption)
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                                premiumSelectionMenu(
                                    title: "Icon",
                                    subtitle: "A quieter face for HabitQuest on the Home Screen.",
                                    selection: appIconBinding,
                                    options: HabitQuestAppIconChoice.allCases.map {
                                        .init(value: $0, label: $0.displayName, symbolName: appIconSymbolName(for: $0))
                                    }
                                )

                                Button {
                                    Task {
                                        let applied = await personalizationStore.applyAppIconIfPossible()
                                        if applied {
                                            showToast("App icon updated.")
                                        } else {
                                            statusMessage = "This device could not update the app icon."
                                        }
                                    }
                                } label: {
                                    Label("Apply app icon", systemImage: "app.badge")
                                }
                                .habitQuestGlassButtonStyle()
                            }
                        }
                    } else {
                        VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                            PremiumFeaturePreviewCard(
                                entitlementService: environment.premiumEntitlementService,
                                descriptor: PremiumFeature.premiumThemes.gateDescriptor(
                                    origin: .profile,
                                    entryPoint: "Premium theme personalization"
                                ),
                                actionTitle: "Preview themes",
                                onOpenGate: { descriptor in
                                    premiumFeatureGateDescriptor = descriptor
                                }
                            ) {
                                PremiumThemePreviewView()
                            }

                            PremiumFeaturePreviewCard(
                                entitlementService: environment.premiumEntitlementService,
                                descriptor: PremiumFeature.premiumAppIcons.gateDescriptor(
                                    origin: .profile,
                                    entryPoint: "Premium app icon personalization"
                                ),
                                actionTitle: "Preview icons",
                                onOpenGate: { descriptor in
                                    premiumFeatureGateDescriptor = descriptor
                                }
                            ) {
                                PremiumIconPreviewView()
                            }

                            PremiumFeaturePreviewCard(
                                entitlementService: environment.premiumEntitlementService,
                                descriptor: PremiumFeature.advancedGamification.gateDescriptor(
                                    origin: .profile,
                                    entryPoint: "Premium personalization effects"
                                ),
                                actionTitle: "Preview effects",
                                onOpenGate: { descriptor in
                                    premiumFeatureGateDescriptor = descriptor
                                }
                            ) {
                                PremiumGamificationPreviewView()
                            }

                            Text("Any saved Premium personalization stays stored locally and becomes active again if Premium returns.")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider().overlay(HabitQuestDesignSystem.Palette.border(for: colorScheme))

                settingsSection(
                    title: "Data management",
                    subtitle: "Export, delete, or replay onboarding."
                ) {
                    Button {
                        Task { await exportLocalData() }
                    } label: {
                        Label("Export local data", systemImage: "square.and.arrow.up")
                    }
                    .habitQuestGlassButtonStyle(prominent: true)
                    .disabled(isPerformingDataAction)

                    Button(role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    } label: {
                        Label("Delete local data", systemImage: "trash")
                    }
                    .habitQuestGlassButtonStyle()
                    .disabled(isPerformingDataAction)

                    Button {
                        onReplayOnboarding()
                    } label: {
                        Label("Replay onboarding", systemImage: "arrow.counterclockwise")
                    }
                    .habitQuestGlassButtonStyle()
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var footerFinePrint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your data stays on this device unless you export it.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("Accessibility: Reduce Motion, Dynamic Type, and large tap targets are supported.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("App information: Version \(appVersionString) · Build \(appBuildString) · Storage: Local on-device")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.xs)
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Local reminders stay calm and respect quiet hours.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            if notificationAuthorizationStatus == .denied {
                CalmEmptyStateCard(
                    icon: "bell.slash",
                    title: "Notifications are off in iOS",
                    message: "HabitQuest can keep your reminder preferences locally, but iOS is currently blocking delivery on this device.",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                    supportingText: "Open Settings if you want to allow reminders again later.",
                    primaryActionTitle: "Open Settings",
                    primaryAction: openAppSettings,
                )
            } else {
                Toggle("Enable reminders", isOn: remindersEnabledBinding)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)

                Toggle("Promotional suggestions", isOn: promotionalNotificationsEnabledBinding)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)

                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    DatePicker(
                        "Quiet hours start",
                        selection: quietHoursStartBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Quiet hours end",
                        selection: quietHoursEndBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Text("\(notificationPreferences.disabledHabitIDs.count) habits are muted individually.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

                Text("Reminders are local, calm, and never cloud-synced.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

                Text("Promotional suggestions stay rare and only appear when you allow them.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            }
        }
        .habitQuestSurface(.raised)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Appearance")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Choose how HabitQuest follows the system or a fixed theme.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            Picker("Appearance", selection: appearanceModeBinding) {
                ForEach(HabitQuestAppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .habitQuestSurface(.raised)
    }

    private var personalizationCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Personalization")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text(personalizationSubtitle)
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if personalizationStore.canUsePremiumPersonalization {
                VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    premiumSelectionMenu(
                        title: "Theme",
                        subtitle: "Warm visual variants for the whole app.",
                        selection: themeVariantBinding,
                        options: HabitQuestPremiumThemeVariant.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: iconName(for: $0))
                        }
                    )

                    premiumSelectionMenu(
                        title: "Accent palette",
                        subtitle: "Small color shifts for a different feel.",
                        selection: accentPaletteBinding,
                        options: HabitQuestPremiumAccentPalette.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: accentIconName(for: $0))
                        }
                    )

                    premiumSelectionMenu(
                        title: "Card appearance",
                        subtitle: "Adjust the glass and framing of habit cards.",
                        selection: cardAppearanceBinding,
                        options: HabitQuestPremiumCardAppearance.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: cardIconName(for: $0))
                        }
                    )

                    premiumSelectionMenu(
                        title: "Completion effects",
                        subtitle: "Choose how completed habits settle.",
                        selection: completionEffectBinding,
                        options: HabitQuestPremiumCompletionEffectStyle.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: completionIconName(for: $0))
                        }
                    )

                    premiumSelectionMenu(
                        title: "Haptic style",
                        subtitle: "Keep feedback subtle or make it more expressive.",
                        selection: hapticStyleBinding,
                        options: HabitQuestPremiumHapticStyle.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: hapticIconName(for: $0))
                        }
                    )

                    premiumSelectionMenu(
                        title: "Sound style",
                        subtitle: "Silent, soft, or lightly glassy.",
                        selection: soundStyleBinding,
                        options: HabitQuestPremiumSoundStyle.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: soundIconName(for: $0))
                        }
                    )

                    premiumSelectionMenu(
                        title: "Progression cosmetics",
                        subtitle: "Tone the progression language up or down.",
                        selection: progressionCosmeticBinding,
                        options: HabitQuestProgressionCosmeticStyle.allCases.map {
                            .init(value: $0, label: $0.displayName, symbolName: progressionIconName(for: $0))
                        }
                    )

                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Text("App icon")
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        Text("Choose an alternate icon and apply it when supported on this device.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                        premiumSelectionMenu(
                            title: "Icon",
                            subtitle: "A quieter face for HabitQuest on the Home Screen.",
                            selection: appIconBinding,
                            options: HabitQuestAppIconChoice.allCases.map {
                                .init(value: $0, label: $0.displayName, symbolName: appIconSymbolName(for: $0))
                            }
                        )

                        Button {
                            Task {
                                let applied = await personalizationStore.applyAppIconIfPossible()
                                if applied {
                                    showToast("App icon updated.")
                                } else {
                                    statusMessage = "This device could not update the app icon."
                                }
                            }
                        } label: {
                            Label("Apply app icon", systemImage: "app.badge")
                        }
                        .habitQuestGlassButtonStyle()
                    }
                }
            } else {
                VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    PremiumFeaturePreviewCard(
                        entitlementService: environment.premiumEntitlementService,
                        descriptor: PremiumFeature.premiumThemes.gateDescriptor(
                            origin: .profile,
                            entryPoint: "Premium theme personalization"
                        ),
                        actionTitle: "Preview themes",
                        onOpenGate: { descriptor in
                            premiumFeatureGateDescriptor = descriptor
                        }
                    ) {
                        PremiumThemePreviewView()
                    }

                    PremiumFeaturePreviewCard(
                        entitlementService: environment.premiumEntitlementService,
                        descriptor: PremiumFeature.premiumAppIcons.gateDescriptor(
                            origin: .profile,
                            entryPoint: "Premium app icon personalization"
                        ),
                        actionTitle: "Preview icons",
                        onOpenGate: { descriptor in
                            premiumFeatureGateDescriptor = descriptor
                        }
                    ) {
                        PremiumIconPreviewView()
                    }

                    PremiumFeaturePreviewCard(
                        entitlementService: environment.premiumEntitlementService,
                        descriptor: PremiumFeature.advancedGamification.gateDescriptor(
                            origin: .profile,
                            entryPoint: "Premium personalization effects"
                        ),
                        actionTitle: "Preview effects",
                        onOpenGate: { descriptor in
                            premiumFeatureGateDescriptor = descriptor
                        }
                    ) {
                        PremiumGamificationPreviewView()
                    }

                    Text("Any saved Premium personalization stays stored locally and becomes active again if Premium returns.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var premiumDiscoveryCard: some View {
        Group {
            if environment.premiumEntitlementService.accessState.isPremiumOrTrial {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Premium options")
                            .font(HabitQuestDesignSystem.Typography.headline)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        Text("A few Premium options stay visible so you can explore what’s available.")
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                        PremiumFeaturePreviewCard(
                            entitlementService: environment.premiumEntitlementService,
                            descriptor: PremiumFeature.premiumThemes.gateDescriptor(
                                origin: .profile,
                                entryPoint: "Premium theme preview"
                            ),
                            actionTitle: "Preview themes",
                            onOpenGate: { descriptor in
                                premiumFeatureGateDescriptor = descriptor
                            }
                        ) {
                            PremiumThemePreviewView()
                        }

                        PremiumFeaturePreviewCard(
                            entitlementService: environment.premiumEntitlementService,
                            descriptor: PremiumFeature.premiumAppIcons.gateDescriptor(
                                origin: .profile,
                                entryPoint: "Premium app icon preview"
                            ),
                            actionTitle: "Preview icons",
                            onOpenGate: { descriptor in
                                premiumFeatureGateDescriptor = descriptor
                            }
                        ) {
                            PremiumIconPreviewView()
                        }

                        PremiumFeaturePreviewCard(
                            entitlementService: environment.premiumEntitlementService,
                            descriptor: PremiumFeature.advancedWidgets.gateDescriptor(
                                origin: .profile,
                                entryPoint: "Premium widget preview"
                            ),
                            actionTitle: "Preview widgets",
                            onOpenGate: { descriptor in
                                premiumFeatureGateDescriptor = descriptor
                            }
                        ) {
                            PremiumWidgetPreviewView()
                        }
                    }
                }
                .habitQuestSurface(.raised)
            }
        }
    }

    private var accessibilityCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Accessibility")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("HabitQuest respects system accessibility settings.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            SettingInfoRow(
                title: "Reduce Motion",
                value: reduceMotion ? "Enabled" : "Off"
            )

            SettingInfoRow(
                title: "Dynamic Type",
                value: dynamicTypeSize.readableDescription
            )

            SettingInfoRow(
                title: "Large tap targets",
                value: "Built in"
            )

            Text("The app keeps animations soft and readable, and it scales with your text size.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
        }
        .habitQuestSurface(.raised)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Privacy")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("HabitQuest keeps your data on this device by default.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            Text("Your habits, progress, achievements, and reminders live on this device unless you explicitly export them.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("No cloud account, sync, or external analytics are used.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .habitQuestSurface(.raised)
    }

    private var settingsOverviewCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Settings")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Everything here stays on your device. No cloud features to configure.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                SettingBadge(title: "Local-first")
                SettingBadge(title: "Native iOS")
                SettingBadge(title: "No account")
            }
        }
        .habitQuestSurface(.raised)
    }

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
                Circle()
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.65))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Premium")
                        .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text(premiumSubtitle)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    if environment.premiumEntitlementService.accessState.isPremiumOrTrial {
                        isPresentingPremiumDetail = true
                    } else {
                        premiumFeatureGateDescriptor = PremiumFeature.advancedCustomization.gateDescriptor(
                            origin: .profile,
                            entryPoint: "Profile Premium card"
                        )
                    }
                } label: {
                    Text(premiumActionTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: 140)
                }
                .habitQuestGlassButtonStyle()
            }

            if environment.premiumEntitlementService.accessState.isPremiumOrTrial {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    statusPill(
                        title: premiumStatusTitle,
                        icon: "sparkles",
                        accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                    )

                    if environment.premiumEntitlementService.subscriptionStatus?.isActiveTrial == true {
                        statusPill(
                            title: "7-day trial",
                            icon: "hourglass",
                            accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                        )
                    }
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Data management")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Export or clear your local dataset from here.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            Button {
                Task { await exportLocalData() }
            } label: {
                Label("Export local data", systemImage: "square.and.arrow.up")
            }
            .habitQuestGlassButtonStyle(prominent: true)
            .disabled(isPerformingDataAction)

            Button(role: .destructive) {
                isPresentingDeleteConfirmation = true
            } label: {
                Label("Delete local data", systemImage: "trash")
            }
            .habitQuestGlassButtonStyle()
            .disabled(isPerformingDataAction)

            Button {
                onReplayOnboarding()
            } label: {
                Label("Replay onboarding", systemImage: "arrow.counterclockwise")
            }
            .habitQuestGlassButtonStyle()

            Text("Deleting local data removes habits, history, milestones, reminders, and settings from this device.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
        }
        .habitQuestSurface(.raised)
    }

    private var appInformationCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("App information")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text("Basic version details for support and clarity.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            SettingInfoRow(title: "Version", value: appVersionString)
            SettingInfoRow(title: "Build", value: appBuildString)
            SettingInfoRow(title: "Storage", value: "Local on-device")
        }
        .habitQuestSurface(.raised)
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
    }

    private var profileDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "Local member" {
            let alias = profileAlias.trimmingCharacters(in: .whitespacesAndNewlines)
            return alias.isEmpty ? "Stillwater" : alias
        }

        return trimmed
    }

    private var profileAvatarSymbol: String {
        let trimmed = profileAvatarSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "leaf.fill" : trimmed
    }

    private var profileAvatarImage: UIImage? {
        guard !profileAvatarImageData.isEmpty else {
            return nil
        }

        return UIImage(data: profileAvatarImageData)
    }

    private var displayInitials: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "HQ"
        }

        let pieces = trimmed.split(separator: " ").prefix(2)
        let initials = pieces.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "HQ" : initials.uppercased()
    }

    private var achievementCatalogDefinitions: [HabitAchievementDefinition] {
        HabitAchievementCatalog.definitions(for: habits)
    }

    private var achievementRows: [AchievementRowModel] {
        let earnedByID = Dictionary(uniqueKeysWithValues: achievements.map { ($0.id, $0) })
        let rows = achievementCatalogDefinitions.map { definition -> AchievementRowModel in
            if let earned = earnedByID[definition.id] {
                return AchievementRowModel(
                    id: definition.id,
                    title: definition.title,
                    detail: definition.detail,
                    symbolName: definition.symbolName,
                    isEarned: true,
                    earnedAt: earned.earnedAt
                )
            }

            return AchievementRowModel(
                id: definition.id,
                title: definition.title,
                detail: definition.detail,
                symbolName: definition.symbolName,
                isEarned: false,
                earnedAt: nil
            )
        }

        return rows.sorted {
            if $0.isEarned != $1.isEarned {
                return $0.isEarned && !$1.isEarned
            }

            switch ($0.earnedAt, $1.earnedAt) {
            case let (lhs?, rhs?):
                return lhs > rhs
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                return $0.id < $1.id
            }
        }
    }

    private var appearanceModeBinding: Binding<HabitQuestAppearanceMode> {
        Binding(
            get: { HabitQuestAppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { newValue in
                appearanceModeRaw = newValue.rawValue
            }
        )
    }

    private var personalizationSubtitle: String {
        if personalizationStore.canUsePremiumPersonalization {
            return "Premium personalization is active. Changes here update the local look and feel without affecting the free design system."
        }

        return "Preview extra themes, icons, and feedback styles. Saved Premium choices stay stored locally and reappear if Premium returns."
    }

    private var themeVariantBinding: Binding<HabitQuestPremiumThemeVariant> {
        Binding(
            get: { personalizationStore.selection.themeVariant },
            set: { personalizationStore.updateThemeVariant($0) }
        )
    }

    private var accentPaletteBinding: Binding<HabitQuestPremiumAccentPalette> {
        Binding(
            get: { personalizationStore.selection.accentPalette },
            set: { personalizationStore.updateAccentPalette($0) }
        )
    }

    private var cardAppearanceBinding: Binding<HabitQuestPremiumCardAppearance> {
        Binding(
            get: { personalizationStore.selection.cardAppearance },
            set: { personalizationStore.updateCardAppearance($0) }
        )
    }

    private var completionEffectBinding: Binding<HabitQuestPremiumCompletionEffectStyle> {
        Binding(
            get: { personalizationStore.selection.completionEffectStyle },
            set: { personalizationStore.updateCompletionEffectStyle($0) }
        )
    }

    private var hapticStyleBinding: Binding<HabitQuestPremiumHapticStyle> {
        Binding(
            get: { personalizationStore.selection.hapticStyle },
            set: { personalizationStore.updateHapticStyle($0) }
        )
    }

    private var soundStyleBinding: Binding<HabitQuestPremiumSoundStyle> {
        Binding(
            get: { personalizationStore.selection.soundStyle },
            set: { personalizationStore.updateSoundStyle($0) }
        )
    }

    private var progressionCosmeticBinding: Binding<HabitQuestProgressionCosmeticStyle> {
        Binding(
            get: { personalizationStore.selection.progressionCosmeticStyle },
            set: { personalizationStore.updateProgressionCosmeticStyle($0) }
        )
    }

    private var appIconBinding: Binding<HabitQuestAppIconChoice> {
        Binding(
            get: { personalizationStore.selection.appIcon },
            set: { personalizationStore.updateAppIcon($0) }
        )
    }

    private func premiumSelectionMenu<Value: Hashable>(
        title: String,
        subtitle: String,
        selection: Binding<Value>,
        options: [PremiumSelectionOption<Value>]
    ) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            Text(subtitle)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Label(option.label, systemImage: option.symbolName ?? "circle")
                        .tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .habitQuestInputField()
        }
    }

    private func iconName(for variant: HabitQuestPremiumThemeVariant) -> String {
        switch variant {
        case .standard:
            return "circle.lefthalf.filled"
        case .dawn:
            return "sunrise.fill"
        case .ember:
            return "flame.fill"
        case .dusk:
            return "moon.stars.fill"
        }
    }

    private func accentIconName(for palette: HabitQuestPremiumAccentPalette) -> String {
        switch palette {
        case .amber:
            return "circle.fill"
        case .clay:
            return "paintbrush.fill"
        case .sage:
            return "leaf.fill"
        case .ocean:
            return "drop.fill"
        }
    }

    private func cardIconName(for appearance: HabitQuestPremiumCardAppearance) -> String {
        switch appearance {
        case .standard:
            return "rectangle.on.rectangle"
        case .spacious:
            return "rectangle.expand.vertical"
        case .framed:
            return "square.grid.3x3"
        case .glassier:
            return "rectangle.inset.filled"
        }
    }

    private func completionIconName(for style: HabitQuestPremiumCompletionEffectStyle) -> String {
        switch style {
        case .subtle:
            return "circle"
        case .luminous:
            return "sparkles"
        case .orbital:
            return "circle.hexagongrid"
        case .ripple:
            return "water.waves"
        }
    }

    private func hapticIconName(for style: HabitQuestPremiumHapticStyle) -> String {
        switch style {
        case .balanced:
            return "hand.raised"
        case .minimal:
            return "dot.radiowaves.left.and.right"
        case .expressive:
            return "waveform"
        }
    }

    private func soundIconName(for style: HabitQuestPremiumSoundStyle) -> String {
        switch style {
        case .silent:
            return "speaker.slash.fill"
        case .soft:
            return "speaker.wave.1.fill"
        case .glass:
            return "speaker.wave.2.fill"
        }
    }

    private func progressionIconName(for style: HabitQuestProgressionCosmeticStyle) -> String {
        switch style {
        case .minimal:
            return "minus"
        case .halo:
            return "circle.dashed"
        case .orb:
            return "sparkles"
        }
    }

    private func appIconSymbolName(for icon: HabitQuestAppIconChoice) -> String {
        switch icon {
        case .defaultIcon:
            return "app.badge"
        case .ember:
            return "flame.fill"
        case .dawn:
            return "sunrise.fill"
        case .dusk:
            return "moon.stars.fill"
        }
    }

    private func beginEditingProfileIdentity() {
        draftDisplayName = profileDisplayName
        draftAvatarSymbolName = profileAvatarSymbol
        draftAvatarImageData = profileAvatarImageData
        isPresentingProfileEditor = true
    }

    private func saveProfileIdentity() {
        let trimmedName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmedName.isEmpty ? "" : trimmedName

        let trimmedAvatar = draftAvatarSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        profileAvatarSymbolName = trimmedAvatar.isEmpty ? randomProfileAvatarSymbol() : trimmedAvatar
        profileAvatarImageData = draftAvatarImageData

        isPresentingProfileEditor = false
        showToast("Profile updated.")
    }

    private func ensureProfileIdentityDefaults() {
        if profileAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profileAlias = randomProfileAlias()
        }

        if profileAvatarSymbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profileAvatarSymbolName = randomProfileAvatarSymbol()
        }
    }

    private func randomProfileAlias() -> String {
        let aliases = [
            "Stillwater Bloom",
            "Quiet Meadow",
            "Moss Lantern",
            "Soft Cedar",
            "Moonlit Stream",
            "Breezy Lotus",
            "Golden Willow",
            "Calm Harbor",
            "Dawn Pebble",
            "Hush Bloom",
            "Serene Grove",
            "Cloud Harbor",
            "Gentle Tide",
            "Drift Meadow",
            "Warm Spruce",
            "Lumen Field"
        ]

        return aliases.randomElement() ?? "Stillwater Bloom"
    }

    private func randomProfileAvatarSymbol() -> String {
        let symbols = [
            "leaf.fill",
            "moon.stars.fill",
            "sparkles",
            "sunrise.fill",
            "drop.fill",
            "wind",
            "cloud.sun.fill",
            "water.waves"
        ]

        return symbols.randomElement() ?? "leaf.fill"
    }

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        return shortVersion
    }

    private var appBuildString: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleVersion"] as? String) ?? "1"
    }

    private var premiumSubtitle: String {
        if environment.premiumEntitlementService.accessState.isPremiumOrTrial {
            return "Premium is currently active on this device."
        }

        if environment.premiumEntitlementService.isEligibleForIntroOffer {
            return "You can still start the 7-day trial from here."
        }

        return "Explore what Premium includes whenever you're ready."
    }

    private var premiumActionTitle: String {
        if environment.premiumEntitlementService.accessState.subscriptionStatus?.isActiveTrial == true {
            return "Premium Trial"
        }

        if environment.premiumEntitlementService.accessState.subscriptionStatus?.isActivePaid == true {
            return "Manage Subscription"
        }

        return environment.premiumEntitlementService.isEligibleForIntroOffer ? "Try Premium Free" : "Go Premium"
    }

    private var premiumStatusTitle: String {
        if environment.premiumEntitlementService.subscriptionStatus?.isActiveTrial == true {
            return "Trial active"
        }

        if environment.premiumEntitlementService.subscriptionStatus?.isActivePaid == true {
            return "Premium active"
        }

        return "Premium active"
    }

    private var remindersEnabledBinding: Binding<Bool> {
        Binding(
            get: { notificationPreferences.isEnabled },
            set: { newValue in
                notificationPreferences.setGlobalEnabled(newValue)
                saveNotificationPreferences()
            }
        )
    }

    private var quietHoursStartBinding: Binding<Date> {
        Binding(
            get: { date(for: notificationPreferences.quietHours.start) },
            set: { newValue in
                notificationPreferences.quietHours.start = clockTime(from: newValue)
                saveNotificationPreferences()
            }
        )
    }

    private var quietHoursEndBinding: Binding<Date> {
        Binding(
            get: { date(for: notificationPreferences.quietHours.end) },
            set: { newValue in
                notificationPreferences.quietHours.end = clockTime(from: newValue)
                saveNotificationPreferences()
            }
        )
    }

    private var promotionalNotificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { notificationPreferences.arePromotionalNotificationsEnabled },
            set: { newValue in
                notificationPreferences.setPromotionalNotificationsEnabled(newValue)
                saveNotificationPreferences()
            }
        )
    }

    private func loadProfileContent() async {
        let calendar = environment.dateService.calendar
        let now = environment.dateService.now
        let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
        let range = start...now

        do {
            let habits = try environment.habitRepository.fetchHabits()
            let completionEvents = try environment.completionEventStore.loadEvents()
            let dailyStates = try environment.dailyHabitStateStore.loadStates()
            let progression = try environment.progressionStore.loadProgression()
            let report = environment.habitAnalyticsCalculator.report(
                for: habits,
                completionEvents: completionEvents,
                dailyStates: dailyStates,
                in: range,
                calendar: calendar
            )

            self.habits = habits
            progressionSummary = environment.habitProgressionCalculator.summary(from: progression)
            achievements = try environment.achievementService.loadAchievements()
            notificationPreferences = try environment.notificationPreferencesStore.loadPreferences()
            notificationAuthorizationStatus = await loadNotificationAuthorizationStatus()
            statistics = ProfileStatisticsSnapshot(
                activeHabits: habits.filter { !$0.isArchived }.count,
                archivedHabits: habits.filter { $0.isArchived }.count,
                totalCompletions: report.totalCompletions,
                currentDailyStreak: environment.dailyStreakCalculator.summary(
                    for: habits,
                    states: dailyStates,
                    completionEvents: completionEvents,
                    upTo: now,
                    calendar: calendar
                ).currentDailyStreak,
                longestDailyStreak: report.personalBests.longestDailyStreak,
                currentMomentum: report.momentumSummary.currentMomentum,
                completionRate: report.completionRate
            )
            statusMessage = nil
        } catch {
            habits = []
            progressionSummary = environment.habitProgressionCalculator.summary(from: .default)
            achievements = []
            statistics = .empty
            notificationPreferences = .default
            notificationAuthorizationStatus = .notDetermined
            statusMessage = "Profile data could not be loaded."
        }
    }

    private func saveNotificationPreferences() {
        do {
            try environment.notificationPreferencesStore.savePreferences(notificationPreferences)
            statusMessage = nil
        } catch {
            statusMessage = "Notification preferences could not be saved."
        }
    }

    private func exportLocalData() async {
        guard !isPerformingDataAction else { return }
        isPerformingDataAction = true
        defer { isPerformingDataAction = false }

        do {
            let exportURL = try environment.localDataManagementService.exportSnapshot(
                profileName: profileDisplayName,
                appearanceMode: appearanceModeBinding.wrappedValue
            )
            exportItem = ProfileExportItem(url: exportURL)
            showToast("Local export ready.")
        } catch {
            statusMessage = "Local export could not be created."
        }
    }

    private func deleteLocalData() async {
        guard !isPerformingDataAction else { return }
        isPerformingDataAction = true
        defer { isPerformingDataAction = false }

        do {
            try environment.localDataManagementService.deleteAllLocalData()
            displayName = ""
            profileAlias = ""
            profileAvatarSymbolName = ""
            profileAvatarImageData = Data()
            appearanceModeRaw = HabitQuestAppearanceMode.system.rawValue
            hasCompletedOnboarding = false
            notificationPreferences = .default
            progressionSummary = environment.habitProgressionCalculator.summary(from: .default)
            achievements = []
            statistics = .empty
            habits = []
            showToast("Local data was deleted.")
        } catch {
            statusMessage = "Local data could not be deleted."
        }
    }

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        statusMessage = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : HabitQuestDesignSystem.Motion.standard) {
            toastMessage = message
        }

        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : HabitQuestDesignSystem.Motion.standard) {
                    toastMessage = nil
                }
            }
        }
    }

    private func loadNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }

    private func date(for time: HabitClockTime) -> Date {
        let calendar = environment.dateService.calendar
        let dayStart = calendar.startOfDay(for: environment.dateService.now)
        return calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: dayStart
        ) ?? dayStart
    }

    private func clockTime(from date: Date) -> HabitClockTime {
        let calendar = environment.dateService.calendar
        return HabitClockTime(
            hour: calendar.component(.hour, from: date),
            minute: calendar.component(.minute, from: date)
        )
    }

    private func statusBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(HabitQuestDesignSystem.Palette.note(for: colorScheme))

            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.base)
    }

    private func statusPill(title: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
        }
        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
        .foregroundStyle(accent)
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.1))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var avatarBadgeView: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.75))
                .frame(width: 64, height: 64)
                .overlay(
                    Circle()
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )

            if let profileAvatarImage {
                Image(uiImage: profileAvatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
            } else {
                Image(systemName: profileAvatarSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            }

            Circle()
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "pencil")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                )
                .overlay(
                    Circle()
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
                .offset(x: 4, y: 4)
        }
    }
}

private struct AchievementsDetailView: View {
    let achievements: [AchievementRowModel]
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Achievements")
                            .font(HabitQuestDesignSystem.Typography.title)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("All achievements stay visible here. Earned ones appear first, while the rest stay quietly faded.")
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                        ForEach(achievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
            .background(HabitQuestScreenBackground())
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        close()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close achievements")
                }
            }
        }
    }

    private func close() {
        onClose()
        dismiss()
    }
}

private struct ProfileIdentityEditorView: View {
    @Binding var displayName: String
    @Binding var avatarSymbolName: String
    @Binding var avatarImageData: Data

    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var avatarSelection: PhotosPickerItem?
    @State private var avatarOptions: [String] = [
        "leaf.fill",
        "moon.stars.fill",
        "sparkles",
        "sunrise.fill",
        "drop.fill",
        "wind",
        "cloud.sun.fill",
        "water.waves",
        "tree.fill",
        "sun.max.fill",
        "hands.sparkles"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit profile")
                            .font(HabitQuestDesignSystem.Typography.title)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("Choose a name, icon, or photo for your local profile.")
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }

                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Text("Profile image")
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("Choose a photo from Photos or keep a gentle icon.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                            PhotosPicker(selection: $avatarSelection, matching: .images) {
                                Label("Choose photo", systemImage: "photo")
                            }
                            .habitQuestGlassButtonStyle(prominent: true)

                            if !avatarImageData.isEmpty {
                                Button("Remove photo") {
                                    avatarImageData = Data()
                                }
                                .habitQuestGlassButtonStyle()
                            }
                        }

                        if let image = UIImage(data: avatarImageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                                )
                                .accessibilityHidden(true)
                        }
                    }

                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Text("Display name")
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        TextField("Display name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .habitQuestInputField()
                    }

                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Text("Icon")
                            .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("Tap an icon if you want a symbol instead of a photo.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HabitQuestDesignSystem.Spacing.sm), count: 4), spacing: HabitQuestDesignSystem.Spacing.sm) {
                            ForEach(avatarOptions, id: \.self) { symbol in
                                Button {
                                    avatarImageData = Data()
                                    avatarSymbolName = symbol
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                            .fill(
                                                symbol == avatarSymbolName && avatarImageData.isEmpty
                                                ? HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.35)
                                                : HabitQuestDesignSystem.Palette.surface(for: colorScheme)
                                            )
                                            .frame(height: 58)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                                    .stroke(
                                                        symbol == avatarSymbolName && avatarImageData.isEmpty
                                                        ? HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                                                        : HabitQuestDesignSystem.Palette.border(for: colorScheme),
                                                        lineWidth: symbol == avatarSymbolName && avatarImageData.isEmpty ? 1.5 : 1
                                                    )
                                            )

                                        Image(systemName: symbol)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(
                                                symbol == avatarSymbolName && avatarImageData.isEmpty
                                                ? HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                                                : HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(symbol.replacingOccurrences(of: ".", with: " ")))
                            }
                        }
                    }

                    Text("Your profile stays local and can be changed anytime.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
            .background(HabitQuestScreenBackground())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: avatarSelection) { _, newItem in
                guard let newItem else { return }

                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            avatarImageData = data
                        }
                    }
                }
            }
        }
    }
}

private struct PremiumSelectionOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    let symbolName: String?

    var id: Value { value }
}

private struct ProfileStatisticsSnapshot: Sendable {
    var activeHabits: Int = 0
    var archivedHabits: Int = 0
    var totalCompletions: Int = 0
    var currentDailyStreak: Int = 0
    var longestDailyStreak: Int = 0
    var currentMomentum: Double = 0
    var completionRate: Double? = nil

    static let empty = ProfileStatisticsSnapshot()
}

private struct MetricTile: View {
    let title: String
    let value: String
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

            Text(value)
                .font(HabitQuestDesignSystem.Typography.title2.weight(.semibold))
                .foregroundStyle(accent)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HabitQuestDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        )
    }
}

private struct MetricPair: View {
    let title: String
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AchievementRowModel: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let isEarned: Bool
    let earnedAt: Date?
}

private struct AchievementRow: View {
    let achievement: AchievementRowModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(achievement.isEarned ? HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.55) : HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .frame(width: 38, height: 38)
                .overlay(
                    Circle()
                        .stroke(
                            achievement.isEarned ? HabitQuestDesignSystem.Palette.border(for: colorScheme) : HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.8),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Image(systemName: achievement.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(achievement.isEarned ? HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme) : HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(achievement.isEarned ? HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme) : HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                Text(achievement.detail)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(achievement.isEarned ? HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme) : HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            }

            if !achievement.isEarned {
                Text("Locked")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(achievement.isEarned ? 1 : 0.45)
    }
}

private struct ProfileToast: View {
    let message: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
        .padding(.vertical, HabitQuestDesignSystem.Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

private struct SettingInfoRow: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Spacer(minLength: 0)

            Text(value)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
    }
}

private struct SettingBadge: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                    )
        )
    }
}

private struct PremiumThemePreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            themeSwatch(color: HabitQuestDesignSystem.Palette.accent(for: colorScheme), label: "Warm")
            themeSwatch(color: HabitQuestDesignSystem.Palette.success(for: colorScheme), label: "Soft")
            themeSwatch(color: HabitQuestDesignSystem.Palette.note(for: colorScheme), label: "Calm")
        }
    }

    private func themeSwatch(color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                .fill(color.opacity(0.35))
                .frame(height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .stroke(color.opacity(0.55), lineWidth: 1)
                )

            Text(label)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PremiumIconPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let icons = ["sun.max.fill", "leaf.fill", "moon.stars.fill"]

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            ForEach(icons, id: \.self) { icon in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                        )

                    Text(icon.replacingOccurrences(of: ".fill", with: ""))
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct PremiumWidgetPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            widgetCard(title: "Today", subtitle: "Deck progress")
            widgetCard(title: "Momentum", subtitle: "Quiet trend")
        }
    }

    private func widgetCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Spacer(minLength: 0)

            Text(subtitle)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(HabitQuestDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        )
    }
}

private struct PremiumGamificationPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            previewRow(symbol: "sparkles", title: "Completion effects", subtitle: "More luminous or subtle finishes")
            previewRow(symbol: "hand.raised", title: "Haptics", subtitle: "Balanced, minimal, or expressive")
            previewRow(symbol: "speaker.wave.1.fill", title: "Sounds", subtitle: "Silent or softly tactile")
        }
    }

    private func previewRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            Circle()
                .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.35))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfileExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension DynamicTypeSize {
    var readableDescription: String {
        switch self {
        case .xSmall:
            return "Extra small"
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .xLarge:
            return "Extra large"
        case .xxLarge:
            return "XX large"
        case .xxxLarge:
            return "XXX large"
        case .accessibility1:
            return "Accessibility 1"
        case .accessibility2:
            return "Accessibility 2"
        case .accessibility3:
            return "Accessibility 3"
        case .accessibility4:
            return "Accessibility 4"
        case .accessibility5:
            return "Accessibility 5"
        @unknown default:
            return "Default"
        }
    }
}
