import SwiftUI

struct CalmEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let accent: Color
    var supportingText: String? = nil
    var primaryActionTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    init(
        icon: String,
        title: String,
        message: String,
        accent: Color = Color.habitQuest(light: 0.78, 0.42, 0.12, dark: 1.00, 0.53, 0.14),
        supportingText: String? = nil,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.accent = accent
        self.supportingText = supportingText
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: HabitQuestDesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.16))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text(message)
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let supportingText {
                Text(supportingText)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if primaryActionTitle != nil || secondaryActionTitle != nil {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    if let primaryActionTitle, let primaryAction {
                        Button(primaryActionTitle) {
                            primaryAction()
                        }
                        .buttonStyle(HabitQuestButtonStyle(role: .primary))
                        .frame(maxWidth: .infinity)
                    }

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle) {
                            secondaryAction()
                        }
                        .buttonStyle(HabitQuestButtonStyle(role: .secondary))
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, HabitQuestDesignSystem.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }
}
