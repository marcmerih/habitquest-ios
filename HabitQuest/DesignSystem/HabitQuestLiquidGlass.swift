import SwiftUI

enum HabitQuestGlassChromeStyle {
    case regular
    case prominent
}

struct HabitQuestGlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundShape)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
                .overlay(
                    shape.stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        } else {
            shape
                .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme))
                .overlay(
                    shape.stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 12, x: 0, y: 8)
        }
    }
}

extension View {
    func habitQuestGlassSurface(
        cornerRadius: CGFloat = HabitQuestDesignSystem.Radius.xl,
        padding: CGFloat = HabitQuestDesignSystem.Spacing.lg
    ) -> some View {
        modifier(HabitQuestGlassSurfaceModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func habitQuestGlassButtonStyle(prominent: Bool = false) -> some View {
        modifier(HabitQuestGlassButtonStyleModifier(prominent: prominent))
    }

    func habitQuestGlassChromeContainer() -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(GlassEffectContainer { self })
        } else {
            return AnyView(self)
        }
    }
}

struct HabitQuestGlassButtonStyleModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(HabitQuestButtonStyle(role: .primary))
            } else {
                content.buttonStyle(HabitQuestButtonStyle(role: .secondary))
            }
        }
    }
}

struct HabitQuestGlassTabBar: View {
    @Binding var selectedTab: MainTab
    @Environment(\.colorScheme) private var colorScheme

    private let items: [(tab: MainTab, title: String, systemImage: String)] = [
        (.today, "Today", "sun.max.fill"),
        (.habits, "Habits", "checklist"),
        (.analytics, "Insights", "chart.bar.fill"),
        (.profile, "Profile", "person.crop.circle.fill")
    ]

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selectedTab = item.tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                        Text(item.title)
                            .font(HabitQuestDesignSystem.Typography.tabLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == item.tab ? activeForeground : inactiveForeground)
                    .background(tabItemBackground(isSelected: selectedTab == item.tab))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
            }
        }
        .padding(8)
        .background(barBackground)
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
        .padding(.bottom, 6)
    }

    private var barBackground: some View {
        let shape = RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xxl, style: .continuous)

        return shape
            .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme).opacity(0.92))
            .overlay(shape.stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1))
            .modifier(HabitQuestGlassBarEffectModifier(shape: shape))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 14, x: 0, y: 10)
    }

    @ViewBuilder
    private func tabItemBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)

        if isSelected {
            if #available(iOS 26.0, *) {
                shape
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.38))
                    .glassEffect(.regular, in: shape)
            } else {
                shape
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
            }
        } else {
            shape.fill(Color.clear)
        }
    }

    private var activeForeground: Color {
        HabitQuestDesignSystem.Palette.accent(for: colorScheme)
    }

    private var inactiveForeground: Color {
        HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme)
    }
}

struct HabitQuestGlassBarEffectModifier<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
        }
    }
}

struct HabitQuestGlassChip: View {
    let title: String
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? HabitQuestDesignSystem.Palette.accent(for: colorScheme) : HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            .background(background)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var background: some View {
        let shape = Capsule(style: .continuous)

        if isSelected {
            if #available(iOS 26.0, *) {
                shape
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.35))
                    .glassEffect(.regular, in: shape)
            } else {
                shape.fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
            }
        } else {
            shape
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    shape.stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        }
    }
}
