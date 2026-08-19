import Foundation
import UIKit

struct AnalyticsContextMetadata: Codable, Equatable, Hashable, Sendable {
    var source: String?
    var featureIdentifier: String?

    init(source: String? = nil, featureIdentifier: String? = nil) {
        self.source = source
        self.featureIdentifier = featureIdentifier
    }
}

protocol DateProviding {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemDateService: DateProviding {
    var now: Date { Date() }
    var calendar: Calendar { .current }
}

protocol HapticServicing {
    var isEnabled: Bool { get }
    @MainActor
    func play(_ event: HabitQuestHapticEvent)
}

struct NoOpHapticService: HapticServicing {
    let isEnabled = false

    @MainActor
    func play(_ event: HabitQuestHapticEvent) {}
}

struct SystemHapticService: HapticServicing {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    @MainActor
    func play(_ event: HabitQuestHapticEvent) {
        guard isEnabled else { return }

        switch event {
        case .swipeThresholdCrossed:
            UISelectionFeedbackGenerator().selectionChanged()
        case .habitCompleted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .habitDeferred:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .habitCreated:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .milestoneReached:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .fullDayCompleted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

enum HabitQuestHapticEvent: String, Sendable {
    case swipeThresholdCrossed
    case habitCompleted
    case habitDeferred
    case habitCreated
    case milestoneReached
    case fullDayCompleted

    var semanticDescription: String {
        switch self {
        case .swipeThresholdCrossed:
            return "swipe threshold crossed"
        case .habitCompleted:
            return "habit completed"
        case .habitDeferred:
            return "habit deferred"
        case .habitCreated:
            return "habit created"
        case .milestoneReached:
            return "milestone reached"
        case .fullDayCompleted:
            return "full day completed"
        }
    }
}

enum AnalyticsEvent: Sendable, Equatable {
    case appLaunched
    case screenViewed(String)
    case habitCompleted(UUID)
    case premiumPaywallViewed(AnalyticsContextMetadata)
    case premiumFeatureGateViewed(AnalyticsContextMetadata)
    case premiumTrialOffered(AnalyticsContextMetadata)
    case premiumTrialDeclined(AnalyticsContextMetadata)
    case premiumTrialStarted(AnalyticsContextMetadata)
    case premiumPurchaseStarted(AnalyticsContextMetadata)
    case premiumPurchaseCompleted(AnalyticsContextMetadata)
    case premiumPurchaseCancelled(AnalyticsContextMetadata)
    case premiumRestoreStarted(AnalyticsContextMetadata)
    case premiumRestoreCompleted(AnalyticsContextMetadata)
    case premiumManageSubscriptionOpened(AnalyticsContextMetadata)

    var analyticsDescription: String {
        switch self {
        case .appLaunched:
            return "app_launched"
        case .screenViewed(let screen):
            return "screen_viewed screen=\(screen.analyticsSourceIdentifier)"
        case .habitCompleted(let habitID):
            return "habit_completed habit_id=\(habitID.uuidString)"
        case .premiumPaywallViewed(let metadata):
            return "premium_paywall_viewed \(metadata.analyticsDescription)"
        case .premiumFeatureGateViewed(let metadata):
            return "premium_feature_gate_viewed \(metadata.analyticsDescription)"
        case .premiumTrialOffered(let metadata):
            return "premium_trial_offered \(metadata.analyticsDescription)"
        case .premiumTrialDeclined(let metadata):
            return "premium_trial_declined \(metadata.analyticsDescription)"
        case .premiumTrialStarted(let metadata):
            return "premium_trial_started \(metadata.analyticsDescription)"
        case .premiumPurchaseStarted(let metadata):
            return "premium_purchase_started \(metadata.analyticsDescription)"
        case .premiumPurchaseCompleted(let metadata):
            return "premium_purchase_completed \(metadata.analyticsDescription)"
        case .premiumPurchaseCancelled(let metadata):
            return "premium_purchase_cancelled \(metadata.analyticsDescription)"
        case .premiumRestoreStarted(let metadata):
            return "premium_restore_started \(metadata.analyticsDescription)"
        case .premiumRestoreCompleted(let metadata):
            return "premium_restore_completed \(metadata.analyticsDescription)"
        case .premiumManageSubscriptionOpened(let metadata):
            return "premium_manage_subscription_opened \(metadata.analyticsDescription)"
        }
    }
}

private extension AnalyticsContextMetadata {
    var analyticsDescription: String {
        var pieces: [String] = []
        if let source {
            pieces.append("source=\(source.analyticsSourceIdentifier)")
        }
        if let featureIdentifier {
            pieces.append("feature=\(featureIdentifier.analyticsSourceIdentifier)")
        }
        return pieces.joined(separator: " ")
    }
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

struct NoOpAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

struct DebugAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics] \(event.analyticsDescription)")
        #endif
    }
}

extension String {
    var analyticsSourceIdentifier: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "unknown"
        }

        let scalars = trimmed.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }

            return "_"
        }

        var collapsed = String(scalars)

        while collapsed.contains("__") {
            collapsed = collapsed.replacingOccurrences(of: "__", with: "_")
        }

        collapsed = collapsed
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()

        return collapsed.isEmpty ? "unknown" : collapsed
    }
}
