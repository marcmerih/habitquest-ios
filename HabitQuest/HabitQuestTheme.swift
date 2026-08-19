import SwiftUI

@available(*, deprecated, message: "Use HabitQuestDesignSystem.Palette and the design-system view modifiers instead.")
enum HabitQuestTheme {
    static let background = Color.habitQuest(light: 0.11, 0.07, 0.05, dark: 0.11, 0.07, 0.05)
    static let surface = Color.habitQuest(light: 0.17, 0.11, 0.08, dark: 0.17, 0.11, 0.08)
    static let surfaceElevated = Color.habitQuest(light: 0.21, 0.14, 0.10, dark: 0.21, 0.14, 0.10)
    static let primaryText = Color.habitQuest(light: 0.98, 0.95, 0.91, dark: 0.98, 0.95, 0.91)
    static let secondaryText = Color.habitQuest(light: 0.80, 0.71, 0.63, dark: 0.80, 0.71, 0.63)
    static let accent = Color.habitQuest(light: 1.00, 0.53, 0.14, dark: 1.00, 0.53, 0.14)
    static let accentSoft = Color.habitQuest(light: 0.35, 0.18, 0.09, dark: 0.35, 0.18, 0.09)
    static let border = Color.white.opacity(0.10)
}

