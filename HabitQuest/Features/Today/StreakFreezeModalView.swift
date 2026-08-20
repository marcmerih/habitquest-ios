import SwiftUI

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
                            .font(HabitQuestDesignSystem.Typography.title1)
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
