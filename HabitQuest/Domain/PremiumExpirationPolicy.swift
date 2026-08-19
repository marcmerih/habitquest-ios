import Foundation

enum PremiumExpirationDisposition: String, Codable, CaseIterable, Hashable, Sendable {
    case preservedAndTemporarilyFallback
    case preservedAndReadOnly
}

struct PremiumExpirationPolicy: Sendable {
    static let shared = PremiumExpirationPolicy()

    func disposition(for feature: PremiumFeature) -> PremiumExpirationDisposition {
        switch feature {
        case .advancedRoutines,
             .advancedScheduling,
             .multipleReminders,
             .smartReminders,
             .advancedWidgets,
             .premiumThemes,
             .premiumAppIcons,
             .advancedCustomization,
             .advancedGamification:
            return .preservedAndTemporarilyFallback

        case .customDaySections,
             .advancedAnalytics,
             .longTermAnalytics,
             .habitInsights,
             .habitReflections:
            return .preservedAndReadOnly
        }
    }

    func preservesStoredData(for feature: PremiumFeature) -> Bool {
        true
    }

    func isReadOnlyWhenExpired(_ feature: PremiumFeature) -> Bool {
        disposition(for: feature) == .preservedAndReadOnly
    }

    func isTemporarilyFallbackWhenExpired(_ feature: PremiumFeature) -> Bool {
        disposition(for: feature) == .preservedAndTemporarilyFallback
    }

    func effectiveSelection(
        for selection: HabitQuestPersonalizationSelection,
        accessState: PremiumAccessState
    ) -> HabitQuestPersonalizationSelection {
        guard accessState.isPremiumOrTrial else {
            return .default
        }

        return selection
    }

    func restorationSummary(for feature: PremiumFeature) -> String {
        switch disposition(for: feature) {
        case .preservedAndTemporarilyFallback:
            return "Stored locally. HabitQuest falls back to the free experience while Premium is inactive."
        case .preservedAndReadOnly:
            return "Stored locally. Editing pauses while Premium is inactive, but the data remains available."
        }
    }
}
