import Foundation

enum DailyHabitStateStoreError: LocalizedError, Sendable {
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "HabitQuest could not save today’s habit state."
        case .loadFailed:
            return "HabitQuest could not load today’s habit state."
        }
    }
}

protocol DailyHabitStateStoring {
    func loadStates() throws -> [DailyHabitState]
    func saveStates(_ states: [DailyHabitState]) throws
}

extension DailyHabitStateStoring {
    func states(for date: Date, calendar: Calendar = .current) throws -> [DailyHabitState] {
        try loadStates().filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func state(for habitID: UUID, on date: Date, calendar: Calendar = .current) throws -> DailyHabitState? {
        try states(for: date, calendar: calendar).first { $0.habitID == habitID }
    }

    func upsertState(_ state: DailyHabitState, calendar: Calendar = .current) throws {
        var states = try loadStates()
        let normalizedDate = calendar.startOfDay(for: state.date)

        if let index = states.firstIndex(where: { $0.habitID == state.habitID && calendar.isDate($0.date, inSameDayAs: normalizedDate) }) {
            states[index] = state
        } else {
            states.append(state)
        }

        try saveStates(states)
    }
}

final class LocalDailyHabitStateStore: DailyHabitStateStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedStates: [DailyHabitState]

    init(storageURL: URL?, initialStates: [DailyHabitState] = []) {
        self.storageURL = storageURL
        self.cachedStates = initialStates
    }

    static func live() -> LocalDailyHabitStateStore {
        LocalDailyHabitStateStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalDailyHabitStateStore {
        LocalDailyHabitStateStore(storageURL: nil)
    }

    func loadStates() throws -> [DailyHabitState] {
        lock.lock()
        defer { lock.unlock() }

        if let storageURL {
            do {
                let data = try Data(contentsOf: storageURL)
                let states = try HabitPersistenceCodec.decoder.decode([DailyHabitState].self, from: data)
                cachedStates = states
                return states
            } catch {
                if (error as NSError).code == NSFileReadNoSuchFileError {
                    cachedStates = []
                    return []
                }

                throw DailyHabitStateStoreError.loadFailed(underlying: error)
            }
        }

        return cachedStates
    }

    func saveStates(_ states: [DailyHabitState]) throws {
        lock.lock()
        defer { lock.unlock() }

        let sortedStates = states.sorted {
            if $0.date == $1.date {
                return $0.habitID.uuidString < $1.habitID.uuidString
            }
            return $0.date < $1.date
        }

        cachedStates = sortedStates

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(sortedStates)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw DailyHabitStateStoreError.saveFailed(underlying: error)
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedStates = []

        guard let storageURL else {
            return
        }

        let directoryURL = storageURL.deletingLastPathComponent()
        let targetURLs = [storageURL]
        for url in targetURLs where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

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
            .appendingPathComponent("DailyHabitStates.json", isDirectory: false)
    }
}
