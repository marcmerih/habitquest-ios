import Foundation

struct HabitQuestNotificationPreferences: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var arePromotionalNotificationsEnabled: Bool
    var quietHours: NotificationQuietHours
    var disabledHabitIDs: Set<UUID>

    static let `default` = HabitQuestNotificationPreferences(
        isEnabled: true,
        arePromotionalNotificationsEnabled: false,
        quietHours: .default,
        disabledHabitIDs: []
    )

    init(
        isEnabled: Bool,
        arePromotionalNotificationsEnabled: Bool = false,
        quietHours: NotificationQuietHours,
        disabledHabitIDs: Set<UUID>
    ) {
        self.isEnabled = isEnabled
        self.arePromotionalNotificationsEnabled = arePromotionalNotificationsEnabled
        self.quietHours = quietHours
        self.disabledHabitIDs = disabledHabitIDs
    }

    func isHabitRemindersEnabled(for habitID: UUID) -> Bool {
        isEnabled && !disabledHabitIDs.contains(habitID)
    }

    mutating func setHabitRemindersEnabled(_ enabled: Bool, for habitID: UUID) {
        if enabled {
            disabledHabitIDs.remove(habitID)
        } else {
            disabledHabitIDs.insert(habitID)
        }
    }

    mutating func setGlobalEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    mutating func setPromotionalNotificationsEnabled(_ enabled: Bool) {
        arePromotionalNotificationsEnabled = enabled
    }
}

enum NotificationPreferencesStoreError: LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "HabitQuest could not load notification preferences."
        case .saveFailed:
            return "HabitQuest could not save notification preferences."
        }
    }
}

protocol NotificationPreferencesStoring {
    func loadPreferences() throws -> HabitQuestNotificationPreferences
    func savePreferences(_ preferences: HabitQuestNotificationPreferences) throws
}

extension NotificationPreferencesStoring {
    func updatePreferences(_ mutate: (inout HabitQuestNotificationPreferences) -> Void) throws -> HabitQuestNotificationPreferences {
        var preferences = try loadPreferences()
        mutate(&preferences)
        try savePreferences(preferences)
        return preferences
    }
}

final class LocalNotificationPreferencesStore: NotificationPreferencesStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedPreferences: HabitQuestNotificationPreferences

    init(storageURL: URL?, initialPreferences: HabitQuestNotificationPreferences = .default) {
        self.storageURL = storageURL
        self.cachedPreferences = initialPreferences
    }

    static func live() -> LocalNotificationPreferencesStore {
        LocalNotificationPreferencesStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalNotificationPreferencesStore {
        LocalNotificationPreferencesStore(storageURL: nil)
    }

    func loadPreferences() throws -> HabitQuestNotificationPreferences {
        lock.lock()
        defer { lock.unlock() }

        guard let storageURL else {
            return cachedPreferences
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let preferences = try HabitPersistenceCodec.decoder.decode(HabitQuestNotificationPreferences.self, from: data)
            cachedPreferences = preferences
            return preferences
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                cachedPreferences = .default
                return .default
            }

            throw NotificationPreferencesStoreError.loadFailed(underlying: error)
        }
    }

    func savePreferences(_ preferences: HabitQuestNotificationPreferences) throws {
        lock.lock()
        defer { lock.unlock() }

        cachedPreferences = preferences

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(preferences)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw NotificationPreferencesStoreError.saveFailed(underlying: error)
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedPreferences = .default

        guard let storageURL else {
            return
        }

        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }

        let directoryURL = storageURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: directoryURL.path),
            (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path).isEmpty) == true {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    static func defaultStoreURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("HabitQuest", isDirectory: true)
            .appendingPathComponent("NotificationPreferences.json", isDirectory: false)
    }
}
