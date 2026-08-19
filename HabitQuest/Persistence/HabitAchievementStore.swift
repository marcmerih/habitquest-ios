import Foundation

enum HabitAchievementStoreError: LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "HabitQuest could not load achievements."
        case .saveFailed:
            return "HabitQuest could not save achievements."
        }
    }
}

protocol HabitAchievementStoring {
    func loadAchievements() throws -> [HabitAchievement]
    func saveAchievements(_ achievements: [HabitAchievement]) throws
}

extension HabitAchievementStoring {
    func achievementIDs() throws -> Set<String> {
        Set(try loadAchievements().map(\.id))
    }

    func appendAchievements(_ achievements: [HabitAchievement]) throws -> [HabitAchievement] {
        guard !achievements.isEmpty else {
            return try loadAchievements()
        }

        var existing = try loadAchievements()
        let knownIDs = Set(existing.map(\.id))
        let newItems = achievements.filter { !knownIDs.contains($0.id) }
        guard !newItems.isEmpty else {
            return existing
        }

        existing.append(contentsOf: newItems)
        try saveAchievements(existing)
        return existing
    }
}

final class LocalHabitAchievementStore: HabitAchievementStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedAchievements: [HabitAchievement]

    init(storageURL: URL?, initialAchievements: [HabitAchievement] = []) {
        self.storageURL = storageURL
        self.cachedAchievements = initialAchievements
    }

    static func live() -> LocalHabitAchievementStore {
        LocalHabitAchievementStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalHabitAchievementStore {
        LocalHabitAchievementStore(storageURL: nil)
    }

    func loadAchievements() throws -> [HabitAchievement] {
        lock.lock()
        defer { lock.unlock() }

        guard let storageURL else {
            return cachedAchievements.sorted(by: Self.sort)
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let achievements = try HabitPersistenceCodec.decoder.decode([HabitAchievement].self, from: data)
            cachedAchievements = achievements.sorted(by: Self.sort)
            return cachedAchievements
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                cachedAchievements = []
                return []
            }

            throw HabitAchievementStoreError.loadFailed(underlying: error)
        }
    }

    func saveAchievements(_ achievements: [HabitAchievement]) throws {
        lock.lock()
        defer { lock.unlock() }

        let sortedAchievements = achievements.sorted(by: Self.sort)
        cachedAchievements = sortedAchievements

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(sortedAchievements)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw HabitAchievementStoreError.saveFailed(underlying: error)
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedAchievements = []

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
            .appendingPathComponent("Achievements.json", isDirectory: false)
    }

    private static func sort(_ lhs: HabitAchievement, _ rhs: HabitAchievement) -> Bool {
        if lhs.earnedAt == rhs.earnedAt {
            return lhs.id < rhs.id
        }

        return lhs.earnedAt < rhs.earnedAt
    }
}
