import SwiftUI

struct AuthLandingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var emailAddress = ""
    @State private var isShowingEmailEntry = false

    let onContinueToHome: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xl) {
                header

                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    AuthProviderButton(
                        title: "Continue with Apple",
                        icon: "apple.logo",
                        style: .primary,
                        action: onContinueToHome
                    )

                    AuthProviderButton(
                        title: "Continue with Gmail",
                        icon: "envelope.fill",
                        style: .secondary,
                        action: onContinueToHome
                    )

                    AuthProviderButton(
                        title: "Continue with GitHub",
                        icon: "chevron.left.forwardslash.chevron.right",
                        style: .secondary,
                        action: onContinueToHome
                    )

                    AuthProviderButton(
                        title: "Use email instead",
                        icon: "at",
                        style: .subtle,
                        action: {
                            withAnimation(HabitQuestDesignSystem.Motion.standard) {
                                isShowingEmailEntry.toggle()
                            }
                        }
                    )
                }

                if isShowingEmailEntry {
                    emailEntryCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                footer
            }
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
            .padding(.top, HabitQuestDesignSystem.Spacing.lg)
            .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
        }
        .background(HabitQuestScreenBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
                    .frame(width: 54, height: 54)

                Text("HQ")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("Getting started is easy")
                    .font(HabitQuestDesignSystem.Typography.display)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Choose the method that feels simplest for now. Each option takes you straight into the app so you can start exploring.")
                    .font(HabitQuestDesignSystem.Typography.body)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, HabitQuestDesignSystem.Spacing.xs)
    }

    private var emailEntryCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Continue with email")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            TextField("Email address", text: $emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .habitQuestInputField()

            Button("Continue", action: onContinueToHome)
                .habitQuestGlassButtonStyle(prominent: true)
                .disabled(emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        }
        .habitQuestGlassSurface(cornerRadius: HabitQuestDesignSystem.Radius.xl)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text("Local first by default")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Data is stored locally on this device unless cloud sync is explicitly enabled later for sharing across devices.")
                .font(HabitQuestDesignSystem.Typography.footnote)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AuthProviderButton: View {
    enum Style {
        case primary
        case secondary
        case subtle
    }

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                iconBadge

                Text(title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(foregroundColor)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.lg)
            .padding(.vertical, HabitQuestDesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }
        .habitQuestGlassButtonStyle(prominent: style == .primary)
        .accessibilityLabel(Text(title))
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.sm, style: .continuous)
                .fill(badgeBackground)
                .frame(width: 36, height: 36)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(badgeForeground)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        case .secondary:
            return HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme)
        case .subtle:
            return HabitQuestDesignSystem.Palette.surface(for: colorScheme)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .subtle:
            return HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.white.opacity(0.12)
        case .secondary:
            return HabitQuestDesignSystem.Palette.border(for: colorScheme)
        case .subtle:
            return HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.75)
        }
    }

    private var badgeBackground: Color {
        switch style {
        case .primary:
            return Color.white.opacity(0.10)
        case .secondary:
            return HabitQuestDesignSystem.Palette.backgroundSoft(for: colorScheme)
        case .subtle:
            return HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme)
        }
    }

    private var badgeForeground: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
        case .subtle:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        }
    }
}
