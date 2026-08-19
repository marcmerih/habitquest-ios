import Foundation

enum HabitQuestWidgetAppGroup {
    static let identifier = "group.com.habitquest.ios"
}

enum HabitQuestWidgetAccessTier: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case trial
    case premium

    var allowsAdvancedWidgets: Bool {
        self == .trial || self == .premium
    }
}

struct HabitQuestWidgetHabitSummary: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var icon: String?
    var category: String?
    var accentHex: String?
    var dailyRhythmRaw: String
    var currentStreak: Int
    var completionRate: Double?
    var isPaused: Bool
    var isArchived: Bool
    var sectionID: UUID?
    var sectionName: String?
}

struct HabitQuestWidgetDaySectionSummary: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var icon: String?
    var order: Int
    var isActive: Bool
    var periodRaw: String?
    var subtitle: String?
}

struct HabitQuestWidgetMetricsSummary: Codable, Equatable, Hashable, Sendable {
    var todayCompleted: Int
    var todayRemaining: Int
    var currentDailyStreak: Int
    var longestDailyStreak: Int
    var currentMomentum: Double
    var completionRate: Double?
}

struct HabitQuestWidgetSnapshot: Codable, Equatable, Hashable, Sendable {
    var generatedAt: Date
    var accessTierRaw: String
    var habits: [HabitQuestWidgetHabitSummary]
    var sections: [HabitQuestWidgetDaySectionSummary]
    var metrics: HabitQuestWidgetMetricsSummary

    static let empty = HabitQuestWidgetSnapshot(
        generatedAt: .now,
        accessTierRaw: HabitQuestWidgetAccessTier.free.rawValue,
        habits: [],
        sections: [],
        metrics: HabitQuestWidgetMetricsSummary(
            todayCompleted: 0,
            todayRemaining: 0,
            currentDailyStreak: 0,
            longestDailyStreak: 0,
            currentMomentum: 0,
            completionRate: nil
        )
    )

    var accessTier: HabitQuestWidgetAccessTier {
        HabitQuestWidgetAccessTier(rawValue: accessTierRaw) ?? .free
    }
}

struct HabitQuestWidgetConfigurationSnapshot: Codable, Equatable, Hashable, Sendable {
    var habitIDs: [UUID]
    var sectionID: UUID?
    var presentationRaw: String
    var progressTypeRaw: String?

    init(
        habitIDs: [UUID] = [],
        sectionID: UUID? = nil,
        presentationRaw: String = "standard",
        progressTypeRaw: String? = nil
    ) {
        self.habitIDs = habitIDs
        self.sectionID = sectionID
        self.presentationRaw = presentationRaw
        self.progressTypeRaw = progressTypeRaw
    }
}

final class HabitQuestWidgetSnapshotStore {
    nonisolated(unsafe) static let shared = HabitQuestWidgetSnapshotStore()

    private enum Storage {
        static let snapshotKey = "habitquest.widgets.snapshot"
        static let configurationKey = "habitquest.widgets.configuration"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults? = nil) {
        self.userDefaults = userDefaults ?? UserDefaults(suiteName: HabitQuestWidgetAppGroup.identifier) ?? .standard
    }

    func loadSnapshot() -> HabitQuestWidgetSnapshot {
        guard
            let data = userDefaults.data(forKey: Storage.snapshotKey),
            let snapshot = try? JSONDecoder().decode(HabitQuestWidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    func saveSnapshot(_ snapshot: HabitQuestWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        userDefaults.set(data, forKey: Storage.snapshotKey)
    }

    func updateAccessTier(_ tier: HabitQuestWidgetAccessTier) {
        var snapshot = loadSnapshot()
        snapshot.accessTierRaw = tier.rawValue
        snapshot.generatedAt = .now
        saveSnapshot(snapshot)
    }

    func saveConfiguration(_ configuration: HabitQuestWidgetConfigurationSnapshot) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        userDefaults.set(data, forKey: Storage.configurationKey)
    }

    func loadConfiguration() -> HabitQuestWidgetConfigurationSnapshot {
        guard
            let data = userDefaults.data(forKey: Storage.configurationKey),
            let configuration = try? JSONDecoder().decode(HabitQuestWidgetConfigurationSnapshot.self, from: data)
        else {
            return HabitQuestWidgetConfigurationSnapshot()
        }

        return configuration
    }
}
