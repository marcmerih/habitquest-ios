import Foundation
import CoreData

final class LocalHabitRepository: HabitRepository {
    private var stack: HabitPersistenceStack
    private let isInMemoryOnly: Bool

    init(stack: HabitPersistenceStack, isInMemoryOnly: Bool) {
        self.stack = stack
        self.isInMemoryOnly = isInMemoryOnly
    }

    static func live() -> LocalHabitRepository {
        if let stack = try? HabitPersistenceStack(inMemoryOnly: false) {
            return LocalHabitRepository(stack: stack, isInMemoryOnly: false)
        }

        return inMemory()
    }

    static func inMemory() -> LocalHabitRepository {
        guard let stack = try? HabitPersistenceStack(inMemoryOnly: true) else {
            fatalError("Unable to create in-memory HabitQuest persistence stack.")
        }

        return LocalHabitRepository(stack: stack, isInMemoryOnly: true)
    }

    func reset() throws {
        stack.context.reset()

        if !isInMemoryOnly {
            try Self.removePersistentStoreFiles()
        }

        guard let freshStack = try? HabitPersistenceStack(inMemoryOnly: isInMemoryOnly) else {
            throw HabitPersistenceError.containerUnavailable
        }

        stack = freshStack
    }

    func fetchHabits() throws -> [Habit] {
        let records = try fetchRecords()
        return try records.map { try $0.asDomainHabit() }
    }

    func fetchActiveHabits(on date: Date, calendar: Calendar) throws -> [Habit] {
        try fetchHabits().filter { $0.isActive(on: date, calendar: calendar) }
    }

    @discardableResult
    func createHabit(_ habit: Habit) throws -> Habit {
        if try fetchRecord(id: habit.id) != nil {
            throw HabitPersistenceError.duplicateHabit(habit.id)
        }

        var habitToStore = habit
        if habitToStore.displayOrder == 0 {
            habitToStore.displayOrder = try nextDisplayOrder()
        }

        _ = try HabitEntity(context: stack.context, habit: habitToStore)
        try saveContext()
        return habitToStore
    }

    @discardableResult
    func updateHabit(_ habit: Habit) throws -> Habit {
        guard let record = try fetchRecord(id: habit.id) else {
            throw HabitPersistenceError.habitNotFound(habit.id)
        }

        try record.apply(habit)
        try saveContext()
        return habit
    }

    func archiveHabit(id: UUID) throws {
        try mutateHabit(id: id) { habit in
            habit.isArchived = true
            habit.updatedAt = .now
        }
    }

    func setHabitPaused(id: UUID, isPaused: Bool) throws {
        try mutateHabit(id: id) { habit in
            habit.isPaused = isPaused
            habit.updatedAt = .now
        }
    }

    func deleteHabit(id: UUID) throws {
        guard let record = try fetchRecord(id: id) else {
            throw HabitPersistenceError.habitNotFound(id)
        }

        stack.context.delete(record)
        try saveContext()
    }

    private func fetchRecords() throws -> [HabitEntity] {
        let request = HabitEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(HabitEntity.displayOrder), ascending: false),
            NSSortDescriptor(key: #keyPath(HabitEntity.createdAt), ascending: false)
        ]

        do {
            return try stack.context.fetch(request)
        } catch {
            throw HabitPersistenceError.decodeFailed(underlying: error)
        }
    }

    private func fetchRecord(id: UUID) throws -> HabitEntity? {
        try fetchRecords().first(where: { $0.id == id })
    }

    private func mutateHabit(id: UUID, mutation: (HabitEntity) throws -> Void) throws {
        guard let record = try fetchRecord(id: id) else {
            throw HabitPersistenceError.habitNotFound(id)
        }

        try mutation(record)
        try saveContext()
    }

    private func saveContext() throws {
        do {
            if stack.context.hasChanges {
                try stack.context.save()
            }
        } catch {
            throw HabitPersistenceError.saveFailed(underlying: error)
        }
    }

    private func nextDisplayOrder() throws -> Int64 {
        let habits = try fetchHabits()
        return (habits.map(\.displayOrder).max() ?? 0) + 1
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
