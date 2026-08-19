import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
                        .frame(width: 92, height: 92)
                    Circle()
                        .stroke(HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.65), lineWidth: 1)
                        .frame(width: 92, height: 92)
                    Text("HQ")
                        .font(HabitQuestDesignSystem.Typography.title2)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                }

                VStack(spacing: 6) {
                    Text("HabitQuest")
                        .font(HabitQuestDesignSystem.Typography.title)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    Text("Getting things ready")
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                ProgressView()
                    .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    .scaleEffect(1.1)
                    .padding(.top, 10)
            }
            .padding(32)
            .habitQuestSurface(.floating)
            .padding(.horizontal, 28)
        }
    }
}
