import Foundation
import XCTest
@testable import HabitQuest

@MainActor
final class LocalPersistenceTests: XCTestCase {
    func testCreateFetchAndUpdateHabit() throws {
        let repository = LocalHabitRepository.inMemory()
        let now = Self.referenceDate
        let habit = Habit(
            title: "Read",
            notes: "Ten pages",
            icon: "book",
            colorHex: "#FFAA00",
            category: "Learning",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .anytime,
            difficulty: 2,
            createdAt: now,
            updatedAt: now
        )

        try repository.createHabit(habit)

        let fetched = try repository.fetchHabits()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Read")

        var updated = habit
        updated.title = "Read longer"
        updated.updatedAt = now.addingTimeInterval(60)
        try repository.updateHabit(updated)

        let reloaded = try repository.fetchHabits()
        XCTAssertEqual(reloaded.first?.title, "Read longer")
    }

    func testArchivePauseAndDeleteHabit() throws {
        let repository = LocalHabitRepository.inMemory()
        let now = Self.referenceDate
        let habit = Habit(
            title: "Workout",
            schedule: .weekly(days: [.monday]),
            createdAt: now,
            updatedAt: now
        )

        try repository.createHabit(habit)
        try repository.setHabitPaused(id: habit.id, isPaused: true)

        let paused = try repository.fetchHabits().first
        XCTAssertEqual(paused?.isPaused, true)

        try repository.archiveHabit(id: habit.id)

        let archived = try repository.fetchHabits().first
        XCTAssertEqual(archived?.isArchived, true)

        try repository.deleteHabit(id: habit.id)
        XCTAssertEqual(try repository.fetchHabits().count, 0)
    }

    func testFetchActiveHabitsFiltersArchivedAndPausedHabits() throws {
        let repository = LocalHabitRepository.inMemory()
        let now = Self.referenceDate

        let activeHabit = Habit(
            title: "Active",
            schedule: .daily,
            createdAt: now,
            updatedAt: now
        )
        let pausedHabit = Habit(
            title: "Paused",
            isPaused: true,
            schedule: .daily,
            createdAt: now,
            updatedAt: now
        )
        let archivedHabit = Habit(
            title: "Archived",
            isArchived: true,
            schedule: .daily,
            createdAt: now,
            updatedAt: now
        )

        try repository.createHabit(activeHabit)
        try repository.createHabit(pausedHabit)
        try repository.createHabit(archivedHabit)

        let activeHabits = try repository.fetchActiveHabits(on: now, calendar: Self.calendar)
        XCTAssertEqual(activeHabits.map(\.title), ["Active"])
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let referenceDate = makeDate(year: 2026, month: 8, day: 17, hour: 9, minute: 0)

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
