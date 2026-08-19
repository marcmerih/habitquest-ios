import Foundation
import CoreData

enum CompletionEventStoreError: LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "HabitQuest could not load completion history."
        case .saveFailed:
            return "HabitQuest could not save completion history."
        }
    }
}

protocol CompletionEventStoring {
    func loadEvents() throws -> [CompletionEvent]
    func saveEvents(_ events: [CompletionEvent]) throws
    func updateReflection(for eventID: UUID, reflection: String?) throws -> CompletionEvent?
}

extension CompletionEventStoring {
    func completionEvent(for habitID: UUID, on logicalCompletionDate: Date, calendar: Calendar = .current) throws -> CompletionEvent? {
        let targetDay = calendar.startOfDay(for: logicalCompletionDate)
        return try loadEvents().first {
            $0.habitID == habitID && calendar.isDate(calendar.startOfDay(for: $0.logicalCompletionDate), inSameDayAs: targetDay)
        }
    }

    func completions(for habitID: UUID) throws -> [CompletionEvent] {
        try loadEvents()
            .filter { $0.habitID == habitID }
            .sorted { lhs, rhs in
                if lhs.logicalCompletionDate == rhs.logicalCompletionDate {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.logicalCompletionDate < rhs.logicalCompletionDate
            }
    }

    func completions(on date: Date, calendar: Calendar = .current) throws -> [CompletionEvent] {
        let targetDay = calendar.startOfDay(for: date)
        return try loadEvents()
            .filter { calendar.isDate($0.logicalCompletionDate, inSameDayAs: targetDay) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func completions(in dateRange: ClosedRange<Date>, calendar: Calendar = .current) throws -> [CompletionEvent] {
        let start = calendar.startOfDay(for: dateRange.lowerBound)
        let end = calendar.startOfDay(for: dateRange.upperBound)
        return try loadEvents()
            .filter {
                let day = calendar.startOfDay(for: $0.logicalCompletionDate)
                return (start...end).contains(day)
            }
            .sorted { lhs, rhs in
                if lhs.logicalCompletionDate == rhs.logicalCompletionDate {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.logicalCompletionDate < rhs.logicalCompletionDate
            }
    }

    func totalCompletionCount() throws -> Int {
        try loadEvents().count
    }

    @discardableResult
    func upsertCompletion(_ event: CompletionEvent, calendar: Calendar = .current) throws -> CompletionEvent {
        var events = try loadEvents()
        let targetDay = calendar.startOfDay(for: event.logicalCompletionDate)

        if let existingIndex = events.firstIndex(where: {
            $0.habitID == event.habitID && calendar.isDate($0.logicalCompletionDate, inSameDayAs: targetDay)
        }) {
            return events[existingIndex]
        }

        let normalizedEvent = CompletionEvent(
            id: event.id,
            habitID: event.habitID,
            timestamp: event.timestamp,
            logicalCompletionDate: targetDay,
            source: event.source
        )

        events.append(normalizedEvent)
        try saveEvents(events)
        return normalizedEvent
    }

    func updateReflection(for eventID: UUID, reflection: String?) throws -> CompletionEvent? {
        var events = try loadEvents()
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            return nil
        }

        let trimmedReflection = reflection?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        events[index].reflection = trimmedReflection
        try saveEvents(events)
        return events[index]
    }
}

final class LocalCompletionEventStore: CompletionEventStoring {
    private var stack: HabitPersistenceStack
    private let isInMemoryOnly: Bool
    private let lock = NSLock()
    private var cachedEvents: [CompletionEvent]

    init(stack: HabitPersistenceStack, isInMemoryOnly: Bool, initialEvents: [CompletionEvent] = []) {
        self.stack = stack
        self.isInMemoryOnly = isInMemoryOnly
        self.cachedEvents = initialEvents
    }

    static func live() -> LocalCompletionEventStore {
        if let stack = try? HabitPersistenceStack(inMemoryOnly: false) {
            return LocalCompletionEventStore(stack: stack, isInMemoryOnly: false)
        }

        return inMemory()
    }

    static func inMemory() -> LocalCompletionEventStore {
        guard let stack = try? HabitPersistenceStack(inMemoryOnly: true) else {
            fatalError("Unable to create an in-memory HabitQuest completion event store.")
        }

        return LocalCompletionEventStore(stack: stack, isInMemoryOnly: true)
    }

    func reset() throws {
        lock.lock()
        defer { lock.unlock() }

        stack.context.reset()

        if !isInMemoryOnly {
            try Self.removePersistentStoreFiles()
        }

        guard let freshStack = try? HabitPersistenceStack(inMemoryOnly: isInMemoryOnly) else {
            throw CompletionEventStoreError.saveFailed(underlying: HabitPersistenceError.containerUnavailable)
        }

        stack = freshStack
        cachedEvents = []
    }

    func loadEvents() throws -> [CompletionEvent] {
        lock.lock()
        defer { lock.unlock() }

        let request = CompletionEventEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CompletionEventEntity.logicalCompletionDate), ascending: true),
            NSSortDescriptor(key: #keyPath(CompletionEventEntity.timestamp), ascending: true)
        ]

        do {
            let records = try stack.context.fetch(request)
            let events = try records.map { try $0.asDomainCompletionEvent() }
            cachedEvents = events
            return events
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                cachedEvents = []
                return []
            }

            throw CompletionEventStoreError.loadFailed(underlying: error)
        }
    }

    func saveEvents(_ events: [CompletionEvent]) throws {
        lock.lock()
        defer { lock.unlock() }

        let normalizedEvents = events
            .map { event in
                CompletionEvent(
                    id: event.id,
                    habitID: event.habitID,
                    timestamp: event.timestamp,
                    logicalCompletionDate: event.logicalCompletionDate,
                    source: event.source
                )
            }
            .sorted {
                if $0.logicalCompletionDate == $1.logicalCompletionDate {
                    if $0.timestamp == $1.timestamp {
                        return $0.id.uuidString < $1.id.uuidString
                    }

                    return $0.timestamp < $1.timestamp
                }

                return $0.logicalCompletionDate < $1.logicalCompletionDate
            }

        var seenKeys = Set<String>()
        let deduplicatedEvents = normalizedEvents.filter { event in
            let key = "\(event.habitID.uuidString)-\(event.logicalCompletionDate.timeIntervalSinceReferenceDate)"
            return seenKeys.insert(key).inserted
        }

        cachedEvents = deduplicatedEvents

        let request = CompletionEventEntity.fetchRequest()

        do {
            let existingRecords = try stack.context.fetch(request)
            existingRecords.forEach { stack.context.delete($0) }

            for event in deduplicatedEvents {
                _ = try CompletionEventEntity(context: stack.context, event: event)
            }

            if stack.context.hasChanges {
                try stack.context.save()
            }
        } catch {
            throw CompletionEventStoreError.saveFailed(underlying: error)
        }
    }

    private static func removePersistentStoreFiles() throws {
        let baseURL = HabitPersistenceStack.defaultStoreURL()
        let storeURLs = [
            baseURL,
            URL(fileURLWithPath: baseURL.path + "-wal"),
            URL(fileURLWithPath: baseURL.path + "-shm")
        ]

        for url in storeURLs where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
