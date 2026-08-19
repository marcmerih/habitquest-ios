import XCTest
@testable import HabitQuest

final class PremiumFeatureGateDescriptorTests: XCTestCase {
    func testAdvancedAnalyticsDescriptorUsesContextualCopyAndSourceMetadata() {
        let descriptor = PremiumFeature.advancedAnalytics.gateDescriptor(
            origin: .analytics,
            entryPoint: "Analytics tab"
        )

        XCTAssertEqual(descriptor.feature, .advancedAnalytics)
        XCTAssertEqual(descriptor.headline, "Understand the patterns behind your progress.")
        XCTAssertTrue(descriptor.explanation.contains("See deeper patterns"))
        XCTAssertEqual(descriptor.previewSymbolName, "chart.bar.xaxis")
        XCTAssertEqual(descriptor.paywallSourceMetadata.origin, .analytics)
        XCTAssertEqual(descriptor.paywallSourceMetadata.entryPoint, "Analytics tab")
        XCTAssertEqual(descriptor.paywallSourceMetadata.feature, .advancedAnalytics)
    }

    func testAdvancedCustomizationDescriptorIsPremiumFriendlyAndProfileAware() {
        let descriptor = PremiumFeature.advancedCustomization.gateDescriptor(
            origin: .profile,
            entryPoint: "Profile Premium card"
        )

        XCTAssertEqual(descriptor.feature, .advancedCustomization)
        XCTAssertEqual(descriptor.headline, "Tune the details so the app fits your rhythm.")
        XCTAssertTrue(descriptor.explanation.contains("Shape HabitQuest around your preferences"))
        XCTAssertEqual(descriptor.paywallSourceMetadata.displayLabel, "Profile · Advanced Customization")
    }
}
