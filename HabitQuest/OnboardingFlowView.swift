import SwiftUI

struct OnboardingFlowView: View {
    enum Mode {
        case firstLaunch
        case replay

        var showsCloseButton: Bool {
            switch self {
            case .firstLaunch:
                return false
            case .replay:
                return true
            }
        }

        var primaryActionTitle: String {
            switch self {
            case .firstLaunch:
                return "Start with Habits"
            case .replay:
                return "Done"
            }
        }
    }

    struct Page: Identifiable {
        let id = UUID()
        let eyebrow: String
        let title: String
        let body: String
        let artwork: Artwork
        let accent: Color
    }

    enum Artwork {
        case calmConsistency
        case dailyRitual
        case notNow
        case momentum
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let mode: Mode
    let onFinish: () -> Void
    let onChooseTemplate: (HabitTemplate) -> Void

    init(
        mode: Mode,
        onFinish: @escaping () -> Void,
        onChooseTemplate: @escaping (HabitTemplate) -> Void = { _ in }
    ) {
        self.mode = mode
        self.onFinish = onFinish
        self.onChooseTemplate = onChooseTemplate
    }

    @State private var pageIndex = 0

    private var pages: [Page] {
        [
            Page(
                eyebrow: "Welcome",
                title: "Consistency without pressure.",
                body: "HabitQuest helps you build steady habits without making the app feel like a scorecard.",
                artwork: .calmConsistency,
                accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
            ),
            Page(
                eyebrow: "Today",
                title: "A simple card ritual for your day.",
                body: "Today's habits appear as a quiet stack of cards. One habit, one decision, one gentle step at a time.",
                artwork: .dailyRitual,
                accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
            ),
            Page(
                eyebrow: "No pressure",
                title: "Swipe left means Not Now.",
                body: "HabitQuest treats missed moments as recoverable, not as failure. You can always return later.",
                artwork: .notNow,
                accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
            ),
            Page(
                eyebrow: "Momentum",
                title: "Long-term consistency still counts.",
                body: "Momentum rewards the habit of returning. After this, we’ll take you to Habits so you can create your first one.",
                artwork: .momentum,
                accent: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme)
            )
        ]
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            VStack(spacing: 0) {
                if mode.showsCloseButton {
                    HStack {
                        Spacer()
                        Button("Close", action: onFinish)
                            .font(HabitQuestDesignSystem.Typography.headline)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .habitQuestGlassButtonStyle()
                            .accessibilityLabel(Text("Close onboarding"))
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.sm)
                }

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(
                            page: page,
                            index: index,
                            pageCount: pages.count,
                            isLastPage: index == pages.count - 1,
                            primaryActionTitle: mode.primaryActionTitle,
                            onChooseTemplate: onChooseTemplate,
                            onPrimaryAction: {
                                if index < pages.count - 1 {
                                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : HabitQuestDesignSystem.Motion.card) {
                                        pageIndex = index + 1
                                    }
                                } else {
                                    onFinish()
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? .default : HabitQuestDesignSystem.Motion.card, value: pageIndex)
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingFlowView.Page
    let index: Int
    let pageCount: Int
    let isLastPage: Bool
    let primaryActionTitle: String
    let onChooseTemplate: (HabitTemplate) -> Void
    let onPrimaryAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.xl) {
            Spacer(minLength: HabitQuestDesignSystem.Spacing.sm)

            OnboardingArtworkView(kind: page.artwork, accent: page.accent)
                .frame(height: 300)
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.lg)

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text(page.eyebrow.uppercased())
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .tracking(1.4)

                Text(page.title)
                    .font(HabitQuestDesignSystem.Typography.title)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .font(HabitQuestDesignSystem.Typography.body)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)

                if isLastPage {
                    finalStepCard
                }

            HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                ForEach(0..<pageCount, id: \.self) { dot in
                    Circle()
                        .fill(dot == index ? page.accent : HabitQuestDesignSystem.Palette.border(for: colorScheme))
                        .frame(width: dot == index ? 8 : 6, height: dot == index ? 8 : 6)
                }
            }
            .padding(.top, HabitQuestDesignSystem.Spacing.xs)

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                Button(isLastPage ? primaryActionTitle : "Next", action: onPrimaryAction)
                    .habitQuestGlassButtonStyle(prominent: true)
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.xxxl)

                if isLastPage {
                    Text("We’ll open the Habits tab next.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }
            }
            .padding(.top, HabitQuestDesignSystem.Spacing.xs)

            Spacer(minLength: HabitQuestDesignSystem.Spacing.sm)
        }
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
    }

    private var finalStepCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                Label("Next up", systemImage: "checklist")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(page.accent)

                Text("Create your first habit in a calm, private space.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text("Templates only pre-fill the starting point. You can still change every detail before saving.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(HabitTemplateCatalog.onboardingHighlights) { template in
                        Button {
                            onChooseTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.icon)
                                    .font(HabitQuestDesignSystem.Typography.headline)
                                Text(template.title)
                                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                                Text(template.subtitle)
                                    .font(HabitQuestDesignSystem.Typography.caption)
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                    .lineLimit(2)
                            }
                            .frame(width: 148, alignment: .leading)
                            .padding(HabitQuestDesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                                            .stroke(template.accentColor.opacity(0.35), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Use \(template.title) template"))
                        .accessibilityHint(Text("Starts a new habit with this template."))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestGlassSurface(cornerRadius: HabitQuestDesignSystem.Radius.xl, padding: HabitQuestDesignSystem.Spacing.lg)
    }
}

private extension HabitTemplate {
    var accentColor: Color {
        Color(hex: accentHex) ?? Color.orange
    }
}

private struct OnboardingArtworkView: View {
    let kind: OnboardingFlowView.Artwork
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            switch kind {
            case .calmConsistency:
                calmConsistencyArt
            case .dailyRitual:
                dailyRitualArt
            case .notNow:
                notNowArt
            case .momentum:
                momentumArt
            }
        }
    }

    private var calmConsistencyArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xxl, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme))
                .frame(width: 250, height: 220)
                .offset(y: 20)

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 130, height: 130)
                .offset(x: -80, y: -62)

            VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    .frame(width: 170, height: 74)
                    .overlay(
                        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                            Circle()
                                .fill(accent.opacity(0.20))
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                                    .frame(width: 84, height: 8)
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.55))
                                    .frame(width: 102, height: 6)
                            }
                        }
                        .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
                    )

                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 120, height: 14)
            }
            .offset(y: -2)
        }
    }

    private var dailyRitualArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xxl, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme))
                .frame(width: 240, height: 260)

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(index == 1 ? accent.opacity(0.16) : HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                        .frame(width: 170 - CGFloat(index * 10), height: 48)
                        .overlay(
                            HStack {
                                Circle()
                                    .fill(index == 1 ? accent : HabitQuestDesignSystem.Palette.border(for: colorScheme))
                                    .frame(width: 14, height: 14)
                                Spacer()
                                if index == 1 {
                                    Capsule(style: .continuous)
                                        .fill(accent.opacity(0.28))
                                        .frame(width: 54, height: 10)
                                }
                            }
                            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
                        )
                        .offset(x: CGFloat(index) * 6)
                }
            }
        }
    }

    private var notNowArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xxl, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme))
                .frame(width: 230, height: 250)

            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 112, height: 112)
                .overlay(
                    Image(systemName: "arrow.left")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(accent)
                )
                .offset(x: -52, y: 18)

            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .frame(width: 118, height: 72)
                .overlay(
                    Text("Not Now")
                        .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                )
                .offset(x: 48, y: -42)
        }
    }

    private var momentumArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xxl, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme))
                .frame(width: 260, height: 250)

            Circle()
                .stroke(accent.opacity(0.18), lineWidth: 16)
                .frame(width: 136, height: 136)

            Circle()
                .trim(from: 0, to: 0.74)
                .stroke(accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .frame(width: 136, height: 136)
                .rotationEffect(.degrees(-90))

            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(width: 150, height: 16)
                .offset(y: 86)
        }
    }
}
