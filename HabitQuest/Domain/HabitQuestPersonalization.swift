import SwiftUI
import UIKit

enum HabitQuestPremiumThemeVariant: String, Codable, CaseIterable, Hashable, Sendable {
    case standard
    case dawn
    case ember
    case dusk

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .dawn: return "Dawn"
        case .ember: return "Ember"
        case .dusk: return "Dusk"
        }
    }

    var requiresPremium: Bool {
        self != .standard
    }
}

enum HabitQuestPremiumAccentPalette: String, Codable, CaseIterable, Hashable, Sendable {
    case amber
    case clay
    case sage
    case ocean

    var displayName: String {
        switch self {
        case .amber: return "Amber"
        case .clay: return "Clay"
        case .sage: return "Sage"
        case .ocean: return "Ocean"
        }
    }

    var requiresPremium: Bool {
        self != .amber
    }
}

enum HabitQuestPremiumCardAppearance: String, Codable, CaseIterable, Hashable, Sendable {
    case standard
    case spacious
    case framed
    case glassier

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .spacious: return "Spacious"
        case .framed: return "Framed"
        case .glassier: return "Glassier"
        }
    }

    var requiresPremium: Bool {
        self != .standard
    }
}

enum HabitQuestPremiumCompletionEffectStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case subtle
    case luminous
    case orbital
    case ripple

    var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .luminous: return "Luminous"
        case .orbital: return "Orbital"
        case .ripple: return "Ripple"
        }
    }

    var requiresPremium: Bool {
        self != .subtle
    }
}

enum HabitQuestPremiumHapticStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case balanced
    case minimal
    case expressive

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .minimal: return "Minimal"
        case .expressive: return "Expressive"
        }
    }

    var requiresPremium: Bool {
        self != .balanced
    }
}

enum HabitQuestPremiumSoundStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case silent
    case soft
    case glass

    var displayName: String {
        switch self {
        case .silent: return "Silent"
        case .soft: return "Soft"
        case .glass: return "Glass"
        }
    }

    var requiresPremium: Bool {
        self != .silent
    }
}

enum HabitQuestProgressionCosmeticStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case minimal
    case halo
    case orb

    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .halo: return "Halo"
        case .orb: return "Orb"
        }
    }

    var requiresPremium: Bool {
        self != .minimal
    }
}

enum HabitQuestAppIconChoice: String, Codable, CaseIterable, Hashable, Sendable {
    case defaultIcon
    case ember
    case dawn
    case dusk

    var displayName: String {
        switch self {
        case .defaultIcon: return "Default"
        case .ember: return "Ember"
        case .dawn: return "Dawn"
        case .dusk: return "Dusk"
        }
    }

    var requiresPremium: Bool {
        self != .defaultIcon
    }

    var alternateIconName: String? {
        switch self {
        case .defaultIcon:
            return nil
        case .ember:
            return "AppIconEmber"
        case .dawn:
            return "AppIconDawn"
        case .dusk:
            return "AppIconDusk"
        }
    }
}

struct HabitQuestPersonalizationSelection: Codable, Equatable, Sendable {
    var themeVariant: HabitQuestPremiumThemeVariant
    var accentPalette: HabitQuestPremiumAccentPalette
    var cardAppearance: HabitQuestPremiumCardAppearance
    var completionEffectStyle: HabitQuestPremiumCompletionEffectStyle
    var hapticStyle: HabitQuestPremiumHapticStyle
    var soundStyle: HabitQuestPremiumSoundStyle
    var progressionCosmeticStyle: HabitQuestProgressionCosmeticStyle
    var appIcon: HabitQuestAppIconChoice

    static let `default` = HabitQuestPersonalizationSelection(
        themeVariant: .standard,
        accentPalette: .amber,
        cardAppearance: .standard,
        completionEffectStyle: .subtle,
        hapticStyle: .balanced,
        soundStyle: .silent,
        progressionCosmeticStyle: .minimal,
        appIcon: .defaultIcon
    )
}

struct HabitQuestPersonalizationTheme: Equatable, Sendable {
    let background: Color
    let backgroundSoft: Color
    let surface: Color
    let surfaceRaised: Color
    let surfaceFloating: Color
    let border: Color
    let accent: Color
    let accentSoft: Color
    let accentMuted: Color
    let success: Color
    let note: Color
}

final class HabitQuestPersonalizationStore: ObservableObject, @unchecked Sendable {
    static let shared = HabitQuestPersonalizationStore()

    @Published private(set) var selection: HabitQuestPersonalizationSelection
    @Published private(set) var accessState: PremiumAccessState

    private let userDefaults: UserDefaults
    private let expirationPolicy: PremiumExpirationPolicy

    private enum Storage {
        static let key = "habitquest.personalization.selection"
    }

    init(
        userDefaults: UserDefaults = .standard,
        accessState: PremiumAccessState = .free,
        expirationPolicy: PremiumExpirationPolicy = .shared
    ) {
        self.userDefaults = userDefaults
        self.accessState = accessState
        self.expirationPolicy = expirationPolicy
        if let decoded = userDefaults.data(forKey: Storage.key).flatMap({ try? JSONDecoder().decode(HabitQuestPersonalizationSelection.self, from: $0) }) {
            self.selection = decoded
        } else {
            self.selection = .default
        }
    }

    func update(accessState: PremiumAccessState) {
        self.accessState = accessState
        objectWillChange.send()
    }

    var canUsePremiumPersonalization: Bool {
        accessState.isPremiumOrTrial
    }

    var effectiveSelection: HabitQuestPersonalizationSelection {
        expirationPolicy.effectiveSelection(for: selection, accessState: accessState)
    }

    var effectiveThemeVariant: HabitQuestPremiumThemeVariant {
        canUsePremiumPersonalization ? selection.themeVariant : .standard
    }

    var effectiveAccentPalette: HabitQuestPremiumAccentPalette {
        canUsePremiumPersonalization ? selection.accentPalette : .amber
    }

    var effectiveCardAppearance: HabitQuestPremiumCardAppearance {
        canUsePremiumPersonalization ? selection.cardAppearance : .standard
    }

    var effectiveCompletionEffectStyle: HabitQuestPremiumCompletionEffectStyle {
        canUsePremiumPersonalization ? selection.completionEffectStyle : .subtle
    }

    var effectiveHapticStyle: HabitQuestPremiumHapticStyle {
        canUsePremiumPersonalization ? selection.hapticStyle : .balanced
    }

    var effectiveSoundStyle: HabitQuestPremiumSoundStyle {
        canUsePremiumPersonalization ? selection.soundStyle : .silent
    }

    var effectiveProgressionCosmeticStyle: HabitQuestProgressionCosmeticStyle {
        canUsePremiumPersonalization ? selection.progressionCosmeticStyle : .minimal
    }

    var effectiveAppIcon: HabitQuestAppIconChoice {
        canUsePremiumPersonalization ? selection.appIcon : .defaultIcon
    }

    func updateThemeVariant(_ variant: HabitQuestPremiumThemeVariant) {
        selection.themeVariant = variant
        persist()
    }

    func updateAccentPalette(_ palette: HabitQuestPremiumAccentPalette) {
        selection.accentPalette = palette
        persist()
    }

    func updateCardAppearance(_ appearance: HabitQuestPremiumCardAppearance) {
        selection.cardAppearance = appearance
        persist()
    }

    func updateCompletionEffectStyle(_ style: HabitQuestPremiumCompletionEffectStyle) {
        selection.completionEffectStyle = style
        persist()
    }

    func updateHapticStyle(_ style: HabitQuestPremiumHapticStyle) {
        selection.hapticStyle = style
        persist()
    }

    func updateSoundStyle(_ style: HabitQuestPremiumSoundStyle) {
        selection.soundStyle = style
        persist()
    }

    func updateProgressionCosmeticStyle(_ style: HabitQuestProgressionCosmeticStyle) {
        selection.progressionCosmeticStyle = style
        persist()
    }

    func updateAppIcon(_ icon: HabitQuestAppIconChoice) {
        selection.appIcon = icon
        persist()
    }

    @MainActor
    func applyAppIconIfPossible() async -> Bool {
        guard canUsePremiumPersonalization else {
            return false
        }

        guard UIApplication.shared.supportsAlternateIcons else {
            return selection.appIcon == .defaultIcon
        }

        return await withCheckedContinuation { continuation in
            UIApplication.shared.setAlternateIconName(selection.appIcon.alternateIconName) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    func visualTheme(for colorScheme: ColorScheme) -> HabitQuestPersonalizationTheme {
        let theme = effectiveThemeVariant
        let accent = effectiveAccentPalette
        let isDark = colorScheme == .dark

        let baseBackground: Color
        let baseBackgroundSoft: Color
        let baseSurface: Color
        let baseSurfaceRaised: Color
        let baseSurfaceFloating: Color

        switch theme {
        case .standard:
            baseBackground = .habitQuest(light: 0.97, 0.95, 0.92, dark: 0.11, 0.07, 0.05)
            baseBackgroundSoft = .habitQuest(light: 0.93, 0.89, 0.84, dark: 0.16, 0.11, 0.07)
            baseSurface = .habitQuest(light: 1.00, 0.98, 0.95, dark: 0.18, 0.11, 0.08)
            baseSurfaceRaised = .habitQuest(light: 0.96, 0.93, 0.88, dark: 0.22, 0.14, 0.10)
            baseSurfaceFloating = .habitQuest(light: 1.00, 0.99, 0.97, dark: 0.26, 0.17, 0.12)
        case .dawn:
            baseBackground = .habitQuest(light: 0.98, 0.96, 0.92, dark: 0.13, 0.09, 0.06)
            baseBackgroundSoft = .habitQuest(light: 0.95, 0.91, 0.85, dark: 0.18, 0.12, 0.08)
            baseSurface = .habitQuest(light: 1.00, 0.99, 0.96, dark: 0.20, 0.13, 0.09)
            baseSurfaceRaised = .habitQuest(light: 0.97, 0.94, 0.89, dark: 0.24, 0.16, 0.11)
            baseSurfaceFloating = .habitQuest(light: 1.00, 0.99, 0.98, dark: 0.28, 0.19, 0.13)
        case .ember:
            baseBackground = .habitQuest(light: 0.96, 0.93, 0.89, dark: 0.10, 0.07, 0.05)
            baseBackgroundSoft = .habitQuest(light: 0.91, 0.86, 0.80, dark: 0.15, 0.10, 0.07)
            baseSurface = .habitQuest(light: 1.00, 0.97, 0.94, dark: 0.18, 0.11, 0.08)
            baseSurfaceRaised = .habitQuest(light: 0.95, 0.91, 0.86, dark: 0.22, 0.14, 0.10)
            baseSurfaceFloating = .habitQuest(light: 1.00, 0.98, 0.96, dark: 0.26, 0.17, 0.12)
        case .dusk:
            baseBackground = .habitQuest(light: 0.95, 0.94, 0.92, dark: 0.12, 0.08, 0.06)
            baseBackgroundSoft = .habitQuest(light: 0.90, 0.89, 0.87, dark: 0.17, 0.12, 0.09)
            baseSurface = .habitQuest(light: 0.99, 0.98, 0.96, dark: 0.19, 0.12, 0.09)
            baseSurfaceRaised = .habitQuest(light: 0.96, 0.95, 0.92, dark: 0.23, 0.15, 0.11)
            baseSurfaceFloating = .habitQuest(light: 0.99, 0.99, 0.97, dark: 0.27, 0.18, 0.13)
        }

        let accentColors = colors(for: accent, dark: isDark)
        return HabitQuestPersonalizationTheme(
            background: baseBackground,
            backgroundSoft: baseBackgroundSoft,
            surface: baseSurface,
            surfaceRaised: baseSurfaceRaised,
            surfaceFloating: baseSurfaceFloating,
            border: colorScheme == .dark ? Color.white.opacity(0.10) : .habitQuest(light: 0.31, 0.23, 0.18, dark: 0.31, 0.23, 0.18).opacity(0.12),
            accent: accentColors.primary,
            accentSoft: accentColors.soft,
            accentMuted: accentColors.muted,
            success: .habitQuest(light: 0.30, 0.46, 0.30, dark: 0.46, 0.63, 0.42),
            note: .habitQuest(light: 0.29, 0.42, 0.52, dark: 0.44, 0.55, 0.64)
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(selection) else {
            return
        }

        userDefaults.set(data, forKey: Storage.key)
        objectWillChange.send()
    }

    private func colors(for palette: HabitQuestPremiumAccentPalette, dark: Bool) -> (primary: Color, soft: Color, muted: Color) {
        switch palette {
        case .amber:
            return (
                .habitQuest(light: 0.78, 0.42, 0.12, dark: 1.00, 0.53, 0.14),
                .habitQuest(light: 0.94, 0.81, 0.70, dark: 0.35, 0.18, 0.09),
                .habitQuest(light: 0.86, 0.76, 0.67, dark: 0.26, 0.17, 0.13)
            )
        case .clay:
            return (
                .habitQuest(light: 0.69, 0.39, 0.28, dark: 0.91, 0.55, 0.41),
                .habitQuest(light: 0.90, 0.78, 0.71, dark: 0.34, 0.18, 0.14),
                .habitQuest(light: 0.79, 0.69, 0.63, dark: 0.25, 0.17, 0.15)
            )
        case .sage:
            return (
                .habitQuest(light: 0.35, 0.49, 0.34, dark: 0.52, 0.67, 0.47),
                .habitQuest(light: 0.81, 0.88, 0.80, dark: 0.28, 0.36, 0.27),
                .habitQuest(light: 0.66, 0.74, 0.65, dark: 0.21, 0.28, 0.21)
            )
        case .ocean:
            return (
                .habitQuest(light: 0.27, 0.46, 0.54, dark: 0.42, 0.61, 0.69),
                .habitQuest(light: 0.78, 0.86, 0.90, dark: 0.23, 0.33, 0.38),
                .habitQuest(light: 0.61, 0.70, 0.74, dark: 0.18, 0.24, 0.28)
            )
        }
    }
}

private extension HabitQuestPremiumThemeVariant {
    var themePreviewLabel: String {
        displayName
    }
}
