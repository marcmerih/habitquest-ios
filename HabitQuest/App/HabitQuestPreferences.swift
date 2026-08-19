import SwiftUI

enum HabitQuestAppearanceMode: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "habitquest.appearance.mode"

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum HabitQuestProfileKeys {
    static let displayName = "habitquest.profile.display-name"
}
