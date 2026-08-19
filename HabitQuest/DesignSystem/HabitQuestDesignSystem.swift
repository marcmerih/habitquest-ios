import SwiftUI
import UIKit

enum HabitQuestDesignSystem {
    private static let personalizationStore = HabitQuestPersonalizationStore.shared

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40

        static let pageHorizontal: CGFloat = 20
        static let pageVertical: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
        static let pill: CGFloat = 999
    }

    enum Motion {
        static let snappy = Animation.easeOut(duration: 0.18)
        static let standard = Animation.easeInOut(duration: 0.25)
        static let gentle = Animation.easeInOut(duration: 0.35)
        static let slow = Animation.easeInOut(duration: 0.55)
        static let springy = Animation.spring(response: 0.38, dampingFraction: 0.86)
        static let card = Animation.spring(response: 0.30, dampingFraction: 0.90)
        static let settle = Animation.spring(response: 0.42, dampingFraction: 0.88)
    }

    enum HapticIntent: Sendable {
        case subtleTap
        case softSuccess
        case complete
        case deferAction
        case gentleAlert
        case celebration

        var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .subtleTap:
                return .light
            case .softSuccess:
                return .soft
            case .complete:
                return .medium
            case .deferAction:
                return .rigid
            case .gentleAlert:
                return .soft
            case .celebration:
                return .heavy
            }
        }

        var notificationType: UINotificationFeedbackGenerator.FeedbackType? {
            switch self {
            case .subtleTap, .deferAction:
                return nil
            case .softSuccess, .complete, .celebration:
                return .success
            case .gentleAlert:
                return .warning
            }
        }
    }

    enum Typography {
        static let display = Font.system(.largeTitle, design: .rounded).weight(.semibold)
        static let title = Font.system(.title, design: .rounded).weight(.semibold)
        static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let bodyEmphasis = Font.system(.body, design: .rounded).weight(.medium)
        static let callout = Font.system(.callout, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let button = Font.system(.callout, design: .rounded).weight(.semibold)
        static let tabLabel = Font.system(.caption, design: .rounded).weight(.semibold)
    }

    enum Palette {
        static func theme(for colorScheme: ColorScheme) -> HabitQuestPersonalizationTheme {
            personalizationStore.visualTheme(for: colorScheme)
        }

        static func background(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).background
        }

        static func backgroundSoft(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).backgroundSoft
        }

        static func surface(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).surface
        }

        static func surfaceRaised(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).surfaceRaised
        }

        static func surfaceFloating(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).surfaceFloating
        }

        static func border(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).border
        }

        static func textPrimary(for colorScheme: ColorScheme) -> Color {
            .habitQuest(light: 0.18, 0.12, 0.09, dark: 0.98, 0.95, 0.91)
        }

        static func textSecondary(for colorScheme: ColorScheme) -> Color {
            .habitQuest(light: 0.45, 0.35, 0.29, dark: 0.80, 0.71, 0.63)
        }

        static func textTertiary(for colorScheme: ColorScheme) -> Color {
            .habitQuest(light: 0.58, 0.48, 0.40, dark: 0.68, 0.58, 0.50)
        }

        static func accent(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).accent
        }

        static func accentSoft(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).accentSoft
        }

        static func accentMuted(for colorScheme: ColorScheme) -> Color {
            theme(for: colorScheme).accentMuted
        }

        static func success(for colorScheme: ColorScheme) -> Color {
            .habitQuest(light: 0.30, 0.46, 0.30, dark: 0.46, 0.63, 0.42)
        }

        static func note(for colorScheme: ColorScheme) -> Color {
            .habitQuest(light: 0.29, 0.42, 0.52, dark: 0.44, 0.55, 0.64)
        }

        static func dangerMuted(for colorScheme: ColorScheme) -> Color {
            .habitQuest(light: 0.66, 0.49, 0.43, dark: 0.55, 0.36, 0.30)
        }
    }
}

extension Color {
    static func habitQuest(
        light red: CGFloat,
        _ lightGreen: CGFloat,
        _ lightBlue: CGFloat,
        dark darkRed: CGFloat,
        _ darkGreen: CGFloat,
        _ darkBlue: CGFloat
    ) -> Color {
        Color(uiColor: UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            return UIColor(
                red: isDark ? darkRed : red,
                green: isDark ? darkGreen : lightGreen,
                blue: isDark ? darkBlue : lightBlue,
                alpha: 1
            )
        })
    }
}
