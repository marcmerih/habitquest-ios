import XCTest
@testable import HabitQuest

@MainActor
final class PremiumPromotionManagerTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "HabitQuest.PremiumPromotionManagerTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreeUserCanSeeUnsolicitedPromotionInCalmContext() {
        let manager = makeManager(now: date(day: 1))

        XCTAssertTrue(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .free,
                    now: date(day: 1)
                )
            )
        )
    }

    func testPremiumAndTrialUsersDoNotSeeUnsolicitedPromotions() {
        let manager = makeManager(now: date(day: 1))

        XCTAssertFalse(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .trial,
                    now: date(day: 1)
                )
            )
        )

        XCTAssertFalse(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .premium,
                    now: date(day: 1)
                )
            )
        )
    }

    func testUnsolicitedPromotionIsBlockedDuringSensitiveMoments() {
        let manager = makeManager(now: date(day: 1))

        XCTAssertFalse(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .free,
                    now: date(day: 1),
                    isDuringTodayDeckTaskCompletion: true
                )
            )
        )

        XCTAssertFalse(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .free,
                    now: date(day: 1),
                    isDuringActiveSwipeInteraction: true
                )
            )
        )

        XCTAssertFalse(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .free,
                    now: date(day: 1),
                    isImmediatelyAfterHabitMiss: true
                )
            )
        )

        XCTAssertFalse(
            manager.shouldPresentUnsolicitedPromotion(
                context: PremiumPromotionContext(
                    accessState: .free,
                    now: date(day: 1),
                    isNegativeOrFailureState: true
                )
            )
        )
    }

    func testUnsolicitedPromotionOnlyShowsOncePerSession() {
        let manager = makeManager(now: date(day: 1))
        let context = PremiumPromotionContext(accessState: .free, now: date(day: 1))

        XCTAssertTrue(manager.shouldPresentUnsolicitedPromotion(context: context))
        manager.recordUnsolicitedPromotionPresented(at: date(day: 1))
        XCTAssertFalse(manager.shouldPresentUnsolicitedPromotion(context: context))
    }

    func testUnsolicitedPromotionRespectsSevenDayCooldownAcrossSessions() {
        let firstManager = makeManager(now: date(day: 1))
        let firstContext = PremiumPromotionContext(accessState: .free, now: date(day: 1))

        XCTAssertTrue(firstManager.shouldPresentUnsolicitedPromotion(context: firstContext))
        firstManager.recordUnsolicitedPromotionPresented(at: date(day: 1))

        let secondManager = makeManager(now: date(day: 6))
        let cooldownContext = PremiumPromotionContext(accessState: .free, now: date(day: 6))
        XCTAssertFalse(secondManager.shouldPresentUnsolicitedPromotion(context: cooldownContext))

        let thirdManager = makeManager(now: date(day: 8))
        let eligibleContext = PremiumPromotionContext(accessState: .free, now: date(day: 8))
        XCTAssertTrue(thirdManager.shouldPresentUnsolicitedPromotion(context: eligibleContext))
    }

    func testContextualGatesRespectEntitlementOnly() {
        let manager = makeManager(now: date(day: 1))

        XCTAssertTrue(manager.shouldPresentContextualGate(feature: .advancedAnalytics, accessState: .free))
        XCTAssertFalse(manager.shouldPresentContextualGate(feature: .advancedAnalytics, accessState: .trial))
        XCTAssertFalse(manager.shouldPresentContextualGate(feature: .advancedAnalytics, accessState: .premium))
    }

    private func makeManager(now: Date) -> PremiumPromotionManager {
        let clock = FixedDateService(now: now, calendar: .current)
        return PremiumPromotionManager(userDefaults: userDefaults, clock: clock)
    }

    private func date(day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = 12
        return components.date ?? .now
    }
}

private struct FixedDateService: DateProviding {
    let now: Date
    let calendar: Calendar
}
