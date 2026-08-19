import Foundation
import CoreData

enum HabitPersistenceError: LocalizedError, Sendable {
    case containerUnavailable
    case duplicateHabit(UUID)
    case habitNotFound(UUID)
    case saveFailed(underlying: Error)
    case decodeFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "Habit storage is unavailable right now."
        case .duplicateHabit:
            return "That habit already exists locally."
        case .habitNotFound:
            return "Could not find that habit locally."
        case .saveFailed:
            return "HabitQuest could not save your changes locally."
        case .decodeFailed:
            return "HabitQuest could not read a saved habit."
        }
    }
}

enum HabitPersistenceCodec {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

@objc(HabitEntity)
final class HabitEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var icon: String?
    @NSManaged var colorHex: String?
    @NSManaged var category: String?
    @NSManaged var isArchived: Bool
    @NSManaged var isPaused: Bool
    @NSManaged var scheduleData: Data
    @NSManaged var timeModeData: Data
    @NSManaged var dailyRhythmRawValue: String
    @NSManaged var daySectionID: UUID?
    @NSManaged var displayOrder: Int64
    @NSManaged var advancedScheduleData: Data?
    @NSManaged var reminderConfigurationData: Data?
    @NSManaged var hasDifficulty: Bool
    @NSManaged var difficultyValue: Int16
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    @nonobjc class func fetchRequest() -> NSFetchRequest<HabitEntity> {
        NSFetchRequest<HabitEntity>(entityName: Self.entityName)
    }

    static let entityName = "HabitEntity"

    convenience init(context: NSManagedObjectContext, habit: Habit) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
            throw HabitPersistenceError.containerUnavailable
        }
        self.init(entity: entity, insertInto: context)
        try apply(habit)
    }

    func apply(_ habit: Habit) throws {
        id = habit.id
        title = habit.title
        notes = habit.notes
        icon = habit.icon
        colorHex = habit.colorHex
        category = habit.category
        isArchived = habit.isArchived
        isPaused = habit.isPaused
        scheduleData = try HabitPersistenceCodec.encoder.encode(habit.schedule)
        timeModeData = try HabitPersistenceCodec.encoder.encode(habit.timeMode)
        dailyRhythmRawValue = habit.dailyRhythm.rawValue
        daySectionID = habit.daySectionID
        displayOrder = habit.displayOrder
        if let advancedSchedule = habit.advancedSchedule {
            advancedScheduleData = try HabitPersistenceCodec.encoder.encode(advancedSchedule)
        } else {
            advancedScheduleData = nil
        }
        if let reminderConfiguration = habit.reminderConfiguration {
            reminderConfigurationData = try HabitPersistenceCodec.encoder.encode(reminderConfiguration)
        } else {
            reminderConfigurationData = nil
        }
        hasDifficulty = habit.difficulty != nil
        difficultyValue = Int16(habit.difficulty ?? 0)
        createdAt = habit.createdAt
        updatedAt = habit.updatedAt
    }

    func asDomainHabit() throws -> Habit {
        let schedule = try HabitPersistenceCodec.decoder.decode(HabitSchedule.self, from: scheduleData)
        let timeMode = try HabitPersistenceCodec.decoder.decode(HabitTimeMode.self, from: timeModeData)
        let advancedSchedule: HabitAdvancedSchedule?
        if let advancedScheduleData {
            advancedSchedule = try HabitPersistenceCodec.decoder.decode(HabitAdvancedSchedule.self, from: advancedScheduleData)
        } else {
            advancedSchedule = nil
        }
        let reminderConfiguration: HabitReminderConfiguration?
        if let reminderConfigurationData {
            reminderConfiguration = try HabitPersistenceCodec.decoder.decode(HabitReminderConfiguration.self, from: reminderConfigurationData)
        } else {
            reminderConfiguration = nil
        }

        return Habit(
            id: id,
            title: title,
            notes: notes,
            icon: icon,
            colorHex: colorHex,
            category: category,
            isArchived: isArchived,
            isPaused: isPaused,
            schedule: schedule,
            timeMode: timeMode,
            dailyRhythm: HabitRhythm(rawValue: dailyRhythmRawValue) ?? .anytime,
            daySectionID: daySectionID,
            displayOrder: displayOrder,
            advancedSchedule: advancedSchedule,
            reminderConfiguration: reminderConfiguration,
            difficulty: hasDifficulty ? Int(difficultyValue) : nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@objc(CompletionEventEntity)
final class CompletionEventEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var habitID: UUID
    @NSManaged var timestamp: Date
    @NSManaged var logicalCompletionDate: Date
    @NSManaged var sourceRawValue: String
    @NSManaged var reflection: String?

    @nonobjc class func fetchRequest() -> NSFetchRequest<CompletionEventEntity> {
        NSFetchRequest<CompletionEventEntity>(entityName: Self.entityName)
    }

    static let entityName = "CompletionEventEntity"

    convenience init(context: NSManagedObjectContext, event: CompletionEvent) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
            throw HabitPersistenceError.containerUnavailable
        }
        self.init(entity: entity, insertInto: context)
        apply(event)
    }

    func apply(_ event: CompletionEvent) {
        id = event.id
        habitID = event.habitID
        timestamp = event.timestamp
        logicalCompletionDate = event.logicalCompletionDate
        sourceRawValue = event.source.rawValue
        reflection = event.reflection
    }

    func asDomainCompletionEvent() throws -> CompletionEvent {
        guard let source = CompletionSource(rawValue: sourceRawValue) else {
            throw HabitPersistenceError.decodeFailed(underlying: NSError(
                domain: "HabitQuest.CompletionEventEntity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode completion source."]
            ))
        }

        return CompletionEvent(
            id: id,
            habitID: habitID,
            timestamp: timestamp,
            logicalCompletionDate: logicalCompletionDate,
            source: source,
            reflection: reflection
        )
    }
}

final class HabitPersistenceStack {
    let context: NSManagedObjectContext
    let persistentStoreCoordinator: NSPersistentStoreCoordinator

    init(inMemoryOnly: Bool) throws {
        let model = HabitPersistenceStack.makeModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let storeType = inMemoryOnly ? NSInMemoryStoreType : NSSQLiteStoreType
        let storeURL = inMemoryOnly ? nil : HabitPersistenceStack.defaultStoreURL()
        if let storeURL {
            try HabitPersistenceStack.ensureStoreDirectoryExists(for: storeURL)
        }
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        try coordinator.addPersistentStore(
            ofType: storeType,
            configurationName: nil,
            at: storeURL,
            options: options
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil

        self.context = context
        self.persistentStoreCoordinator = coordinator
    }

    private static func makeModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = HabitEntity.entityName
        entity.managedObjectClassName = NSStringFromClass(HabitEntity.self)

        entity.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false),
            attribute(name: "title", type: .stringAttributeType),
            attribute(name: "notes", type: .stringAttributeType, isOptional: true),
            attribute(name: "icon", type: .stringAttributeType, isOptional: true),
            attribute(name: "colorHex", type: .stringAttributeType, isOptional: true),
            attribute(name: "category", type: .stringAttributeType, isOptional: true),
            attribute(name: "isArchived", type: .booleanAttributeType),
            attribute(name: "isPaused", type: .booleanAttributeType),
            attribute(name: "scheduleData", type: .binaryDataAttributeType),
            attribute(name: "timeModeData", type: .binaryDataAttributeType),
            attribute(name: "dailyRhythmRawValue", type: .stringAttributeType),
            attribute(name: "daySectionID", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "displayOrder", type: .integer64AttributeType),
            attribute(name: "advancedScheduleData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "reminderConfigurationData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "hasDifficulty", type: .booleanAttributeType),
            attribute(name: "difficultyValue", type: .integer16AttributeType),
            attribute(name: "createdAt", type: .dateAttributeType),
            attribute(name: "updatedAt", type: .dateAttributeType)
        ]
        entity.indexes = [
            index(named: "HabitEntityIdIndex", in: entity, propertyNames: ["id"])
        ]

        let completionEventEntity = NSEntityDescription()
        completionEventEntity.name = CompletionEventEntity.entityName
        completionEventEntity.managedObjectClassName = NSStringFromClass(CompletionEventEntity.self)
        completionEventEntity.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false),
            attribute(name: "habitID", type: .UUIDAttributeType, isOptional: false),
            attribute(name: "timestamp", type: .dateAttributeType),
            attribute(name: "logicalCompletionDate", type: .dateAttributeType),
            attribute(name: "sourceRawValue", type: .stringAttributeType),
            attribute(name: "reflection", type: .stringAttributeType, isOptional: true)
        ]
        completionEventEntity.indexes = [
            index(named: "CompletionEventEntityIdIndex", in: completionEventEntity, propertyNames: ["id"]),
            index(named: "CompletionEventEntityHabitIndex", in: completionEventEntity, propertyNames: ["habitID"]),
            index(named: "CompletionEventEntityLogicalDateIndex", in: completionEventEntity, propertyNames: ["logicalCompletionDate"])
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity, completionEventEntity]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }

    private static func index(
        named name: String,
        in entity: NSEntityDescription,
        propertyNames: [String]
    ) -> NSFetchIndexDescription {
        let elements = propertyNames.compactMap { propertyName -> NSFetchIndexElementDescription? in
            guard let property = entity.propertiesByName[propertyName] else {
                return nil
            }

            return NSFetchIndexElementDescription(property: property, collationType: .binary)
        }

        return NSFetchIndexDescription(name: name, elements: elements)
    }

    static func defaultStoreURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("HabitQuest", isDirectory: true)
            .appendingPathComponent("HabitQuest.sqlite", isDirectory: false)
    }

    private static func ensureStoreDirectoryExists(for storeURL: URL) throws {
        let directoryURL = storeURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
}
