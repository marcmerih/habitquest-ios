import Foundation

enum StreakFreezeStoreError: LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "HabitQuest could not load your streak freeze state."
        case .saveFailed:
            return "HabitQuest could not save your streak freeze state."
        }
    }
}

protocol StreakFreezeStoring {
    func loadState() throws -> StreakFreezeState
    func saveState(_ state: StreakFreezeState) throws
    func recordOpportunity(_ opportunity: StreakFreezeOpportunity) throws
    func reset() throws
}

extension StreakFreezeStoring {
    func updateState(_ mutate: (inout StreakFreezeState) -> Void) throws -> StreakFreezeState {
        var state = try loadState()
        mutate(&state)
        try saveState(state)
        return state
    }
}

final class LocalStreakFreezeStore: StreakFreezeStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedState: StreakFreezeState

    init(storageURL: URL?, initialState: StreakFreezeState = .default) {
        self.storageURL = storageURL
        self.cachedState = initialState
    }

    static func live() -> LocalStreakFreezeStore {
        LocalStreakFreezeStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalStreakFreezeStore {
        LocalStreakFreezeStore(storageURL: nil)
    }

    func loadState() throws -> StreakFreezeState {
        lock.lock()
        defer { lock.unlock() }

        guard let storageURL else {
            return cachedState
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let state = try HabitPersistenceCodec.decoder.decode(StreakFreezeState.self, from: data)
            cachedState = state
            return state
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                cachedState = .default
                return .default
            }

            throw StreakFreezeStoreError.loadFailed(underlying: error)
        }
    }

    func saveState(_ state: StreakFreezeState) throws {
        lock.lock()
        defer { lock.unlock() }

        cachedState = state

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(state)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw StreakFreezeStoreError.saveFailed(underlying: error)
        }
    }

    func recordOpportunity(_ opportunity: StreakFreezeOpportunity) throws {
        try updateState { state in
            if let existing = state.pendingOpportunity {
                if opportunity.brokenDay > existing.brokenDay {
                    state.pendingOpportunity = opportunity
                }
                return
            }

            state.pendingOpportunity = opportunity
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedState = .default

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
            .appendingPathComponent("StreakFreeze.json", isDirectory: false)
    }
}
