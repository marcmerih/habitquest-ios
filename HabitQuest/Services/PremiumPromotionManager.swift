import Foundation
import SwiftUI

struct PremiumPromotionContext: Sendable, Equatable {
    var accessState: PremiumAccessState
    var now: Date
    var isDuringTodayDeckTaskCompletion: Bool
    var isDuringActiveSwipeInteraction: Bool
    var isImmediatelyAfterHabitMiss: Bool
    var isNegativeOrFailureState: Bool

    init(
        accessState: PremiumAccessState,
        now: Date,
        isDuringTodayDeckTaskCompletion: Bool = false,
        isDuringActiveSwipeInteraction: Bool = false,
        isImmediatelyAfterHabitMiss: Bool = false,
        isNegativeOrFailureState: Bool = false
    ) {
        self.accessState = accessState
        self.now = now
        self.isDuringTodayDeckTaskCompletion = isDuringTodayDeckTaskCompletion
        self.isDuringActiveSwipeInteraction = isDuringActiveSwipeInteraction
        self.isImmediatelyAfterHabitMiss = isImmediatelyAfterHabitMiss
        self.isNegativeOrFailureState = isNegativeOrFailureState
    }
}

struct PremiumPromotionPolicy: Sendable, Equatable {
    var unsolicitedCooldown: TimeInterval

    static let `default` = PremiumPromotionPolicy(
        unsolicitedCooldown: 7 * 24 * 60 * 60
    )
}

struct PremiumPromotionState: Codable, Equatable, Sendable {
    var lastUnsolicitedPromptPresentedAt: Date?

    static let empty = PremiumPromotionState(lastUnsolicitedPromptPresentedAt: nil)
}

final class PremiumPromotionManager: ObservableObject, @unchecked Sendable {
    private enum Storage {
        static let key = "habitquest.premium.promotion.state"
    }

    @Published private(set) var state: PremiumPromotionState

    private let userDefaults: UserDefaults
    private let clock: any DateProviding
    private let policy: PremiumPromotionPolicy
    private var didPresentUnsolicitedPromotionThisSession = false

    init(
        userDefaults: UserDefaults = .standard,
        clock: any DateProviding = SystemDateService(),
        policy: PremiumPromotionPolicy = .default
    ) {
        self.userDefaults = userDefaults
        self.clock = clock
        self.policy = policy
        self.state = Self.loadState(from: userDefaults)
    }

    func beginSession() {
        didPresentUnsolicitedPromotionThisSession = false
    }

    func shouldPresentContextualGate(
        feature: PremiumFeature,
        accessState: PremiumAccessState
    ) -> Bool {
        !accessState.canAccess(feature)
    }

    func shouldPresentUnsolicitedPromotion(context: PremiumPromotionContext) -> Bool {
        guard !context.accessState.isPremiumOrTrial else {
            return false
        }

        guard !didPresentUnsolicitedPromotionThisSession else {
            return false
        }

        guard !context.isDuringTodayDeckTaskCompletion else {
            return false
        }

        guard !context.isDuringActiveSwipeInteraction else {
            return false
        }

        guard !context.isImmediatelyAfterHabitMiss else {
            return false
        }

        guard !context.isNegativeOrFailureState else {
            return false
        }

        if let lastPresentedAt = state.lastUnsolicitedPromptPresentedAt {
            let elapsed = context.now.timeIntervalSince(lastPresentedAt)
            if elapsed < policy.unsolicitedCooldown {
                return false
            }
        }

        return true
    }

    func recordUnsolicitedPromotionPresented(at timestamp: Date? = nil) {
        let moment = timestamp ?? clock.now
        didPresentUnsolicitedPromotionThisSession = true
        state.lastUnsolicitedPromptPresentedAt = moment
        persist()
    }

    func resetCooldownState() {
        state = .empty
        didPresentUnsolicitedPromotionThisSession = false
        persist()
    }

    private func persist() {
        guard let data = try? HabitPersistenceCodec.encoder.encode(state) else {
            return
        }

        userDefaults.set(data, forKey: Storage.key)
    }

    private static func loadState(from userDefaults: UserDefaults) -> PremiumPromotionState {
        guard
            let data = userDefaults.data(forKey: Storage.key),
            let state = try? HabitPersistenceCodec.decoder.decode(PremiumPromotionState.self, from: data)
        else {
            return .empty
        }

        return state
    }
}
