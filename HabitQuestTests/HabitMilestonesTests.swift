import Foundation
import XCTest
@testable import HabitQuest

final class HabitMilestonesTests: XCTestCase {
    func testEvaluatorAwardsCoreMilestonesOnce() {
        let evaluator = HabitMilestoneEvaluator()
        let habit = Habit(
            title: "Read",
            createdAt: Self.day1Morning,
            updatedAt: Self.day1Morning
        )

        let habits = [habit]
        let completionEvents = (0..<100).map { offset in
            CompletionEvent(
                habitID: habit.id,
                timestamp: Self.date(byAddingDays: offset),
                logicalCompletionDate: Self.calendar.startOfDay(for: Self.date(byAddingDays: offset)),
                source: .manualHabitAction
            )
        }

        let dailyStates = (0..<100).map { offset in
            DailyHabitState(
                habitID: habit.id,
                date: Self.calendar.startOfDay(for: Self.date(byAddingDays: offset)),
                status: .completed,
                completedAt: Self.date(byAddingDays: offset),
                deckPriority: 10,
                currentPass: 1
            )
        }

        let awards = evaluator.evaluate(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            progression: HabitProgressionState(lifetimeXP: 1000, lastUpdatedAt: Self.day100Noon),
            at: Self.day100Noon,
            calendar: Self.calendar
        )

        XCTAssertTrue(awards.contains(where: { $0.id == "firstHabitCompleted" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "firstFullDayCompleted" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "dailyStreak.7" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "dailyStreak.30" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "momentum.30.80" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "totalCompletions.50" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "totalCompletions.100" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "progressionLevel.2" }))
        XCTAssertTrue(awards.contains(where: { $0.id == "progressionLevel.5" }))

        let repeatedAwards = evaluator.evaluate(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            progression: HabitProgressionState(lifetimeXP: 1000, lastUpdatedAt: Self.day100Noon),
            earnedAchievementIDs: Set(awards.map(\.id)),
            at: Self.day100Noon,
            calendar: Self.calendar
        )

        XCTAssertTrue(repeatedAwards.isEmpty)
    }

    func testStorePersistsAchievementsAndAvoidsDuplicates() throws {
        let store = LocalHabitAchievementStore.inMemory()
        let achievement = HabitAchievement(
            id: "firstHabitCompleted",
            title: "First habit completed",
            detail: "You started moving with your first completion.",
            symbolName: "checkmark.circle.fill",
            earnedAt: Self.day1Morning
        )

        try store.saveAchievements([achievement])
        let firstLoad = try store.loadAchievements()
        XCTAssertEqual(firstLoad.count, 1)

        let merged = try store.appendAchievements([achievement])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(try store.loadAchievements().count, 1)
    }

    func testAchievementCatalogContainsABroadSetOfMilestones() {
        let habits = [
            Habit(title: "Meditate", createdAt: Self.day1Morning, updatedAt: Self.day1Morning),
            Habit(title: "Read", createdAt: Self.day1Morning, updatedAt: Self.day1Morning),
            Habit(title: "Stretch", createdAt: Self.day1Morning, updatedAt: Self.day1Morning)
        ]

        let definitions = HabitAchievementCatalog.definitions(for: habits)

        XCTAssertGreaterThan(definitions.count, 100)
        XCTAssertTrue(definitions.contains(where: { $0.id == "firstHabitCompleted" }))
        XCTAssertTrue(definitions.contains(where: { $0.id.hasPrefix("habitStreak.") }))
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let baseDate = makeDate(year: 2026, month: 8, day: 16, hour: 9, minute: 0)
    private static let day1Morning = date(byAddingDays: 0)
    private static let day100Noon = date(byAddingDays: 99, hour: 12)

    private static func date(byAddingDays days: Int, hour: Int = 9, minute: Int = 0) -> Date {
        let base = baseDate
        return calendar.date(byAdding: .day, value: days, to: base)!
            .settingTime(hour: hour, minute: minute, calendar: calendar)
    }

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

private extension Date {
    func settingTime(hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        return components.date ?? self
    }
}
