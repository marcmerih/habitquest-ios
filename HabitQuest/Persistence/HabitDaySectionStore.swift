import Foundation

enum HabitDaySectionStoreError: LocalizedError, Sendable {
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "HabitQuest could not save your day sections."
        case .loadFailed:
            return "HabitQuest could not load your day sections."
        }
    }
}

protocol HabitDaySectionStoring {
    func loadSections() throws -> [HabitDaySection]
    func saveSections(_ sections: [HabitDaySection]) throws
    func reset() throws
}

extension HabitDaySectionStoring {
    func activeSections() throws -> [HabitDaySection] {
        try loadSections()
            .filter(\.isActive)
            .sorted { $0.order < $1.order }
    }

    func section(with id: UUID) throws -> HabitDaySection? {
        try loadSections().first { $0.id == id }
    }

    func upsertSection(_ section: HabitDaySection) throws {
        var sections = try loadSections()
        if let index = sections.firstIndex(where: { $0.id == section.id }) {
            sections[index] = section
        } else {
            sections.append(section)
        }
        try saveSections(sections)
    }
}

final class LocalHabitDaySectionStore: HabitDaySectionStoring {
    private let storageURL: URL?
    private let lock = NSLock()
    private var cachedSections: [HabitDaySection]

    init(storageURL: URL?, initialSections: [HabitDaySection] = []) {
        self.storageURL = storageURL
        self.cachedSections = initialSections
    }

    static func live() -> LocalHabitDaySectionStore {
        LocalHabitDaySectionStore(storageURL: defaultStoreURL())
    }

    static func inMemory() -> LocalHabitDaySectionStore {
        LocalHabitDaySectionStore(storageURL: nil)
    }

    func loadSections() throws -> [HabitDaySection] {
        lock.lock()
        defer { lock.unlock() }

        if let storageURL {
            do {
                let data = try Data(contentsOf: storageURL)
                let sections = try HabitPersistenceCodec.decoder.decode([HabitDaySection].self, from: data)
                cachedSections = sections
                return sections
            } catch {
                if (error as NSError).code == NSFileReadNoSuchFileError {
                    cachedSections = []
                    return []
                }

                throw HabitDaySectionStoreError.loadFailed(underlying: error)
            }
        }

        return cachedSections
    }

    func saveSections(_ sections: [HabitDaySection]) throws {
        lock.lock()
        defer { lock.unlock() }

        let sortedSections = sections.sorted {
            if $0.order == $1.order {
                return $0.id.uuidString < $1.id.uuidString
            }

            return $0.order < $1.order
        }

        cachedSections = sortedSections

        guard let storageURL else {
            return
        }

        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try HabitPersistenceCodec.encoder.encode(sortedSections)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw HabitDaySectionStoreError.saveFailed(underlying: error)
        }
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedSections = []

        guard let storageURL else {
            return
        }

        let directoryURL = storageURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
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
            .appendingPathComponent("HabitDaySections.json", isDirectory: false)
    }
}
