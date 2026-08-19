import SwiftUI

struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let supportingCopy: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                VStack(spacing: HabitQuestDesignSystem.Spacing.xl) {
                    Spacer(minLength: 12)

                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 104, height: 104)

                        Circle()
                            .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
                            .frame(width: 80, height: 80)

                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Text(title)
                            .font(HabitQuestDesignSystem.Typography.title)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text(subtitle)
                            .font(HabitQuestDesignSystem.Typography.body)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Text("Ready for more")
                            .font(HabitQuestDesignSystem.Typography.headline)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text(supportingCopy)
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .habitQuestSurface(.raised)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
            }
        }
    }
}
