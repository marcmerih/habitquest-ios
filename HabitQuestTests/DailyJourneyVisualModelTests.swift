import XCTest
@testable import HabitQuest

final class DailyJourneyVisualModelTests: XCTestCase {
    func testProgressClampsToExpectedRange() {
        let model = DailyJourneyVisualModel()

        let low = model.state(for: -0.4)
        let high = model.state(for: 1.4)

        XCTAssertEqual(low.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(high.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(low.completionText, "0%")
        XCTAssertEqual(high.completionText, "100%")
    }

    func testVisualStateBecomesBrighterAndMoreBalancedAsProgressIncreases() {
        let model = DailyJourneyVisualModel()

        let zero = model.state(for: 0)
        let half = model.state(for: 0.5)
        let full = model.state(for: 1)

        XCTAssertLessThan(zero.glowOpacity, half.glowOpacity)
        XCTAssertLessThan(half.glowOpacity, full.glowOpacity)

        XCTAssertLessThan(zero.coreScale, half.coreScale)
        XCTAssertLessThan(half.coreScale, full.coreScale)

        XCTAssertGreaterThan(zero.balanceOffset, half.balanceOffset)
        XCTAssertGreaterThan(half.balanceOffset, full.balanceOffset)

        XCTAssertLessThan(zero.arcSpan, half.arcSpan)
        XCTAssertLessThan(half.arcSpan, full.arcSpan)
    }

    func testMidpointRemainsSubtleRatherThanFullyResolved() {
        let model = DailyJourneyVisualModel()

        let mid = model.state(for: 0.5)

        XCTAssertLessThan(mid.progress, 1)
        XCTAssertGreaterThan(mid.progress, 0)
        XCTAssertLessThan(mid.glowOpacity, 0.45)
        XCTAssertLessThan(mid.coreScale, 0.95)
        XCTAssertGreaterThan(mid.balanceOffset, 0)
        XCTAssertLessThan(mid.arcSpan, 1)
    }
}
