import Foundation
import XCTest
@testable import HabitQuest

final class HabitTemplateTests: XCTestCase {
    func testCuratedTemplateCollectionIsSmallAndThoughtful() throws {
        XCTAssertEqual(HabitTemplateCatalog.curated.count, 11)

        let ids = Set(HabitTemplateCatalog.curated.map(\.id))
        XCTAssertTrue(ids.contains("drink-water"))
        XCTAssertTrue(ids.contains("meditate"))
        XCTAssertTrue(ids.contains("sleep-routine"))
    }

    func testTemplateSelectionPrefillsHabitDraft() throws {
        let template = try XCTUnwrap(HabitTemplateCatalog.template(withID: "drink-water"))
        let draft = HabitCreationDraft(mode: .create(template: template), now: Self.referenceDate, calendar: Self.calendar)

        XCTAssertEqual(draft.title, "Drink water")
        XCTAssertEqual(draft.category, "Wellness")
        XCTAssertEqual(draft.dailyRhythm, .anytime)
        XCTAssertEqual(draft.schedule, .daily)
        XCTAssertEqual(draft.timeMode, .allDay)
        XCTAssertEqual(draft.remindersEnabled, true)
        XCTAssertEqual(draft.selectedTemplateID, template.id)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let referenceDate = makeDate(year: 2026, month: 8, day: 16, hour: 12, minute: 0)

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
