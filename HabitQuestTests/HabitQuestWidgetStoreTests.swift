import XCTest
@testable import HabitQuest

final class HabitQuestWidgetStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HabitQuestWidgetStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        XCTAssertNotNil(defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testWidgetConfigurationSurvivesPremiumToFreeTransitionsAndRelaunch() {
        let sectionID = UUID()
        let habitID = UUID()

        do {
            let store = HabitQuestWidgetSnapshotStore(userDefaults: defaults)
            store.saveConfiguration(
                HabitQuestWidgetConfigurationSnapshot(
                    habitIDs: [habitID],
                    sectionID: sectionID,
                    presentationRaw: "routine",
                    progressTypeRaw: "consistency"
                )
            )

            store.updateAccessTier(.premium)

            XCTAssertEqual(store.loadConfiguration().habitIDs, [habitID])
            XCTAssertEqual(store.loadConfiguration().sectionID, sectionID)
            XCTAssertEqual(store.loadSnapshot().accessTier, .premium)

            store.updateAccessTier(.free)

            XCTAssertEqual(store.loadConfiguration().habitIDs, [habitID])
            XCTAssertEqual(store.loadConfiguration().sectionID, sectionID)
            XCTAssertEqual(store.loadSnapshot().accessTier, .free)
        }

        let reloadedStore = HabitQuestWidgetSnapshotStore(userDefaults: defaults)

        XCTAssertEqual(reloadedStore.loadConfiguration().habitIDs, [habitID])
        XCTAssertEqual(reloadedStore.loadConfiguration().sectionID, sectionID)
        XCTAssertEqual(reloadedStore.loadConfiguration().presentationRaw, "routine")
        XCTAssertEqual(reloadedStore.loadConfiguration().progressTypeRaw, "consistency")
        XCTAssertEqual(reloadedStore.loadSnapshot().accessTier, .free)
    }
}
