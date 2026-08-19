import XCTest
@testable import HabitQuest

final class PremiumExpirationPolicyTests: XCTestCase {
    func testPremiumFeatureDispositionMatchesPreservationRules() {
        let policy = PremiumExpirationPolicy.shared

        XCTAssertEqual(policy.disposition(for: .advancedRoutines), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .customDaySections), .preservedAndReadOnly)
        XCTAssertEqual(policy.disposition(for: .advancedScheduling), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .multipleReminders), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .smartReminders), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .advancedAnalytics), .preservedAndReadOnly)
        XCTAssertEqual(policy.disposition(for: .longTermAnalytics), .preservedAndReadOnly)
        XCTAssertEqual(policy.disposition(for: .habitInsights), .preservedAndReadOnly)
        XCTAssertEqual(policy.disposition(for: .habitReflections), .preservedAndReadOnly)
        XCTAssertEqual(policy.disposition(for: .advancedWidgets), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .premiumThemes), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .premiumAppIcons), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .advancedCustomization), .preservedAndTemporarilyFallback)
        XCTAssertEqual(policy.disposition(for: .advancedGamification), .preservedAndTemporarilyFallback)
    }

    func testPremiumFeaturesAlwaysPreserveStoredData() {
        let policy = PremiumExpirationPolicy.shared

        for feature in PremiumFeature.allCases {
            XCTAssertTrue(policy.preservesStoredData(for: feature))
        }
    }

    func testPolicyDescribesCalmFallbackBehavior() {
        let policy = PremiumExpirationPolicy.shared

        XCTAssertTrue(policy.restorationSummary(for: .premiumThemes).contains("Stored locally"))
        XCTAssertTrue(policy.restorationSummary(for: .habitReflections).contains("editing pauses"))
    }
}
