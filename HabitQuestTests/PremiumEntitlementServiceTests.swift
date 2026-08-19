import XCTest
@testable import HabitQuest

final class PremiumEntitlementServiceTests: XCTestCase {
    func testFreeAccessDoesNotAllowPremiumFeatures() {
        let service = PremiumEntitlementService(accessState: .free)

        for feature in PremiumFeature.allCases {
            XCTAssertFalse(service.canAccess(feature), "Expected \(feature.displayName) to be locked for free access.")
        }
    }

    func testTrialAccessAllowsPremiumFeatures() {
        let service = PremiumEntitlementService(accessState: .trial)

        for feature in PremiumFeature.allCases {
            XCTAssertTrue(service.canAccess(feature), "Expected \(feature.displayName) to be available during trial.")
        }
    }

    func testPremiumAccessAllowsPremiumFeatures() {
        let service = PremiumEntitlementService(accessState: .premium)

        for feature in PremiumFeature.allCases {
            XCTAssertTrue(service.canAccess(feature), "Expected \(feature.displayName) to be available with premium access.")
        }
    }

    func testEveryPremiumFeatureRequiresPremiumTier() {
        for feature in PremiumFeature.allCases {
            XCTAssertEqual(feature.minimumRequiredTier, .premium, "Expected \(feature.displayName) to remain a premium capability.")
        }
    }
}
