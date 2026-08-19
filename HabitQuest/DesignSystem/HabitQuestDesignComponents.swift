import SwiftUI

enum HabitQuestSurfaceStyle {
    case base
    case raised
    case floating
}

struct HabitQuestSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    private let personalizationStore = HabitQuestPersonalizationStore.shared

    let style: HabitQuestSurfaceStyle
    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(adjustedPadding)
            .background(
                RoundedRectangle(cornerRadius: adjustedCornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: adjustedCornerRadius, style: .continuous)
                            .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                    )
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: shadowYOffset
                    )
            )
    }

    private var adjustedCornerRadius: CGFloat {
        switch personalizationStore.effectiveCardAppearance {
        case .standard:
            return cornerRadius
        case .spacious:
            return cornerRadius + 4
        case .framed:
            return max(16, cornerRadius - 4)
        case .glassier:
            return cornerRadius + 8
        }
    }

    private var adjustedPadding: CGFloat {
        switch personalizationStore.effectiveCardAppearance {
        case .standard:
            return padding
        case .spacious:
            return padding + 4
        case .framed:
            return padding + 2
        case .glassier:
            return padding
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .base:
            return HabitQuestDesignSystem.Palette.surface(for: colorScheme)
        case .raised:
            return HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme)
        case .floating:
            return HabitQuestDesignSystem.Palette.surfaceFloating(for: colorScheme)
        }
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(style == .floating ? 0.24 : 0.16)
            : .black.opacity(style == .floating ? 0.10 : 0.06)
    }

    private var shadowRadius: CGFloat {
        switch (style, personalizationStore.effectiveCardAppearance) {
        case (.base, .standard):
            return 4
        case (.base, .spacious):
            return 5
        case (.base, .framed):
            return 3
        case (.base, .glassier):
            return 6
        case (.raised, .standard):
            return 10
        case (.raised, .spacious):
            return 11
        case (.raised, .framed):
            return 8
        case (.raised, .glassier):
            return 12
        case (.floating, .standard):
            return 16
        case (.floating, .spacious):
            return 18
        case (.floating, .framed):
            return 14
        case (.floating, .glassier):
            return 20
        }
    }

    private var shadowYOffset: CGFloat {
        if style == .base {
            return 1
        }

        if style == .raised {
            return personalizationStore.effectiveCardAppearance == .framed ? 5 : 6
        }

        return personalizationStore.effectiveCardAppearance == .glassier ? 8 : 10
    }
}

extension View {
    func habitQuestSurface(
        _ style: HabitQuestSurfaceStyle = .raised,
        cornerRadius: CGFloat = HabitQuestDesignSystem.Radius.xl,
        padding: CGFloat = HabitQuestDesignSystem.Spacing.lg
    ) -> some View {
        modifier(HabitQuestSurfaceModifier(style: style, cornerRadius: cornerRadius, padding: padding))
    }

    func softCard() -> some View {
        habitQuestSurface()
    }

    func habitQuestScreenBackground() -> some View {
        background(HabitQuestScreenBackground())
    }
}

struct HabitQuestScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    HabitQuestDesignSystem.Palette.background(for: colorScheme),
                    HabitQuestDesignSystem.Palette.backgroundSoft(for: colorScheme),
                    HabitQuestDesignSystem.Palette.background(for: colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.30))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .offset(x: 140, y: -260)

            Circle()
                .fill(HabitQuestDesignSystem.Palette.success(for: colorScheme).opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 28)
                .offset(x: -130, y: 220)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct HabitQuestButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case subtle
    }

    @Environment(\.colorScheme) private var colorScheme

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HabitQuestDesignSystem.Typography.button)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.lg)
            .background(backgroundShape)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(HabitQuestDesignSystem.Motion.snappy, value: configuration.isPressed)
    }

    private var cornerRadius: CGFloat {
        switch role {
        case .primary:
            return HabitQuestDesignSystem.Radius.xl
        case .secondary:
            return HabitQuestDesignSystem.Radius.lg
        case .subtle:
            return HabitQuestDesignSystem.Radius.lg
        }
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var backgroundColor: Color {
        switch role {
        case .primary:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        case .secondary:
            return HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme)
        case .subtle:
            return HabitQuestDesignSystem.Palette.surface(for: colorScheme)
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return .white
        case .secondary, .subtle:
            return HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme)
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return Color.white.opacity(0.10)
        case .secondary:
            return HabitQuestDesignSystem.Palette.border(for: colorScheme)
        case .subtle:
            return HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.7)
        }
    }
}

struct HabitQuestInputFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.lg)
            .padding(.vertical, HabitQuestDesignSystem.Spacing.md)
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

extension View {
    func habitQuestInputField() -> some View {
        modifier(HabitQuestInputFieldModifier())
    }
}
