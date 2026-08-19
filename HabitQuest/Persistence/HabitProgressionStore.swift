import Foundation

enum HabitProgressionStoreError: LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "HabitQuest could not load progression."
        case .saveFailed:
            return "HabitQuest could not save progression."
        }
    }
}

protocol HabitProgressionStoring {
    func loadProgression() throws -> HabitProgressionState
    func saveProgression(_ progression: HabitProgressionState) throws
}

extension HabitProgressionStoring {
    func updateProgression(_ mutate: (inout HabitProgressionState) -> Void) throws -> HabitProgressionState {
        var progression = try loadProgression()
        mutate(&progression)
        try saveProgression(progression)
        return progression
    }
}

final class LocalHabitProgressionStore: HabitProgressionStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedProgression: HabitProgressionState

    init(storageURL: URL?, initialProgression: HabitProgressionState = .default) {
        self.storageURL = storageURL
        self.cachedProgression = initialProgression
    }

    static func live() -> LocalHabitProgressionStore {
        LocalHabitProgressionStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalHabitProgressionStore {
        LocalHabitProgressionStore(storageURL: nil)
    }

    func loadProgression() throws -> HabitProgressionState {
        lock.lock()
        defer { lock.unlock() }

        guard let storageURL else {
            return cachedProgression
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let progression = try HabitPersistenceCodec.decoder.decode(HabitProgressionState.self, from: data)
            cachedProgression = progression
            return progression
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                cachedProgression = .default
                return .default
            }

            throw HabitProgressionStoreError.loadFailed(underlying: error)
        }
    }

    func saveProgression(_ progression: HabitProgressionState) throws {
        lock.lock()
        defer { lock.unlock() }

        let sanitizedProgression = HabitProgressionState(
            lifetimeXP: max(progression.lifetimeXP, 0),
            lastUpdatedAt: progression.lastUpdatedAt
        )

        cachedProgression = sanitizedProgression

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(sanitizedProgression)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw HabitProgressionStoreError.saveFailed(underlying: error)
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedProgression = .default

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
            .appendingPathComponent("Progression.json", isDirectory: false)
    }
}
