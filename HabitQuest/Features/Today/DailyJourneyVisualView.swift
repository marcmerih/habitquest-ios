import SwiftUI

struct DailyJourneyVisualTheme {
    let backgroundGlow: Color
    let outerArc: Color
    let innerArc: Color
    let core: LinearGradient
    let highlight: Color
    let shell: Color

    static func habitQuest(for colorScheme: ColorScheme) -> Self {
        Self(
            backgroundGlow: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme),
            outerArc: HabitQuestDesignSystem.Palette.note(for: colorScheme),
            innerArc: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
            core: LinearGradient(
                colors: [
                    HabitQuestDesignSystem.Palette.surfaceFloating(for: colorScheme),
                    HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.92),
                    HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            highlight: HabitQuestDesignSystem.Palette.success(for: colorScheme),
            shell: HabitQuestDesignSystem.Palette.border(for: colorScheme)
        )
    }
}

struct DailyJourneyVisualState: Equatable, Sendable {
    let progress: Double
    let easedProgress: Double
    let glowOpacity: Double
    let glowScale: CGFloat
    let coreScale: CGFloat
    let balanceOffset: CGFloat
    let shellOpacity: Double
    let arcSpan: Double

    var completionText: String {
        "\(Int((progress * 100).rounded()))%"
    }
}

struct DailyJourneyVisualModel {
    func state(for progress: Double) -> DailyJourneyVisualState {
        let clampedProgress = max(0, min(progress, 1))
        let easedProgress = Self.smoothstep(clampedProgress)
        let openness = 1 - easedProgress

        return DailyJourneyVisualState(
            progress: clampedProgress,
            easedProgress: easedProgress,
            glowOpacity: 0.16 + (0.34 * easedProgress),
            glowScale: 0.96 + (0.12 * easedProgress),
            coreScale: 0.76 + (0.22 * easedProgress),
            balanceOffset: 14 * openness,
            shellOpacity: 0.18 + (0.28 * easedProgress),
            arcSpan: 0.18 + (0.76 * easedProgress)
        )
    }

    private static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

struct DailyJourneyVisualView: View {
    let progress: Double
    let theme: DailyJourneyVisualTheme
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var displayProgress: Double = 0

    private let model = DailyJourneyVisualModel()

    var body: some View {
        let visual = model.state(for: displayProgress)

        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(theme.backgroundGlow.opacity(visual.glowOpacity))
                    .frame(width: size * 0.92, height: size * 0.92)
                    .blur(radius: reduceMotion ? 14 : 28)
                    .scaleEffect(visual.glowScale)

                Circle()
                    .stroke(theme.shell.opacity(visual.shellOpacity), lineWidth: 1)
                    .frame(width: size * 0.78, height: size * 0.78)
                    .scaleEffect(1 - (0.04 * visual.easedProgress))

                JourneyArcRing(
                    lineWidth: max(6, size * 0.048),
                    trimStart: 0.08,
                    trimSpan: visual.arcSpan,
                    color: theme.outerArc,
                    rotation: -36 + (24 * visual.easedProgress)
                )
                .frame(width: size * 0.80, height: size * 0.80)

                JourneyArcRing(
                    lineWidth: max(4, size * 0.034),
                    trimStart: 0.46,
                    trimSpan: max(0.10, visual.arcSpan * 0.82),
                    color: theme.innerArc,
                    rotation: 108 - (18 * visual.easedProgress)
                )
                .frame(width: size * 0.58, height: size * 0.58)

                JourneyArcRing(
                    lineWidth: max(3, size * 0.022),
                    trimStart: 0.82,
                    trimSpan: max(0.08, visual.arcSpan * 0.66),
                    color: theme.highlight.opacity(0.85),
                    rotation: -18 + (12 * visual.easedProgress)
                )
                .frame(width: size * 0.42, height: size * 0.42)

                Circle()
                    .fill(theme.core)
                    .frame(width: size * visual.coreScale, height: size * visual.coreScale)
                    .shadow(
                        color: theme.highlight.opacity(0.18 + (0.18 * visual.easedProgress)),
                        radius: reduceMotion ? 12 : 20,
                        x: 0,
                        y: 0
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.clear,
                                        theme.highlight.opacity(0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.screen)
                    )

                Circle()
                    .fill(Color.white.opacity(reduceMotion ? 0.10 : 0.16))
                    .frame(width: size * 0.10, height: size * 0.10)
                    .offset(x: size * 0.18, y: -size * 0.10 + visual.balanceOffset * 0.10)
                    .blur(radius: 1)
                    .opacity(0.30 + (0.35 * visual.easedProgress))

                Circle()
                    .fill(theme.highlight.opacity(0.26))
                    .frame(width: size * 0.07, height: size * 0.07)
                    .offset(x: -size * 0.19, y: size * 0.14 - visual.balanceOffset * 0.08)
                    .blur(radius: 1)
                    .opacity(0.18 + (0.28 * visual.easedProgress))

                VStack(spacing: HabitQuestDesignSystem.Spacing.xxs) {
                    Text(visual.completionText)
                        .font(HabitQuestDesignSystem.Typography.title.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        .monospacedDigit()

                    Text("Journey")
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .tracking(1.2)
                }
                .opacity(0.82)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily Journey")
        .accessibilityAddTraits(.isImage)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("A decorative progress visual derived from today's completed habits.")
        .onAppear {
            displayProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                displayProgress = newValue
            } else {
                withAnimation(HabitQuestDesignSystem.Motion.card) {
                    displayProgress = newValue
                }
            }
        }
    }

    private var accessibilityValue: String {
        let percent = Int((max(0, min(progress, 1)) * 100).rounded())

        switch percent {
        case 0:
            return "0 percent complete, no habits complete yet"
        case 100:
            return "100 percent complete, day complete"
        default:
            return "\(percent) percent complete, building toward day complete"
        }
    }
}

private struct JourneyArcRing: View {
    let lineWidth: CGFloat
    let trimStart: Double
    let trimSpan: Double
    let color: Color
    let rotation: Double

    var body: some View {
        Circle()
            .trim(from: trimStart, to: min(trimStart + trimSpan, 0.995))
            .stroke(
                AngularGradient(
                    colors: [
                        color.opacity(0.12),
                        color.opacity(0.85),
                        color.opacity(0.42),
                        color.opacity(0.12)
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .rotationEffect(.degrees(rotation))
            .shadow(color: color.opacity(0.20), radius: lineWidth * 0.45, x: 0, y: 0)
    }
}
