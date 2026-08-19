import Foundation
import SwiftUI

protocol PremiumEntitlementProviding: AnyObject, Sendable {
    var accessState: PremiumAccessState { get }

    func canAccess(_ feature: PremiumFeature) -> Bool
}

final class PremiumEntitlementService: ObservableObject, PremiumEntitlementProviding, @unchecked Sendable {
    @Published private(set) var accessState: PremiumAccessState
    private let personalizationStore: HabitQuestPersonalizationStore?
    private let widgetSnapshotStore: HabitQuestWidgetSnapshotStore?

    init(
        accessState: PremiumAccessState = .free,
        personalizationStore: HabitQuestPersonalizationStore? = nil,
        widgetSnapshotStore: HabitQuestWidgetSnapshotStore? = nil
    ) {
        self.accessState = accessState
        self.personalizationStore = personalizationStore
        self.widgetSnapshotStore = widgetSnapshotStore
        personalizationStore?.update(accessState: accessState)
        widgetSnapshotStore?.updateAccessTier(Self.widgetAccessTier(for: accessState))
    }

    func update(accessState: PremiumAccessState) {
        self.accessState = accessState
        personalizationStore?.update(accessState: accessState)
        widgetSnapshotStore?.updateAccessTier(Self.widgetAccessTier(for: accessState))
    }

    func canAccess(_ feature: PremiumFeature) -> Bool {
        accessState.canAccess(feature)
    }

    var subscriptionStatus: PremiumSubscriptionStatus? {
        accessState.subscriptionStatus
    }

    var isEligibleForIntroOffer: Bool {
        accessState.isEligibleForIntroOffer
    }

    private static func widgetAccessTier(for accessState: PremiumAccessState) -> HabitQuestWidgetAccessTier {
        switch accessState.tier {
        case .free:
            return .free
        case .trial:
            return .trial
        case .premium:
            return .premium
        }
    }
}

final class MockPremiumEntitlementService: PremiumEntitlementProviding, @unchecked Sendable {
    private(set) var accessState: PremiumAccessState

    init(accessState: PremiumAccessState) {
        self.accessState = accessState
    }

    func update(accessState: PremiumAccessState) {
        self.accessState = accessState
    }

    func canAccess(_ feature: PremiumFeature) -> Bool {
        accessState.canAccess(feature)
    }

    var subscriptionStatus: PremiumSubscriptionStatus? {
        accessState.subscriptionStatus
    }

    var isEligibleForIntroOffer: Bool {
        accessState.isEligibleForIntroOffer
    }
}
