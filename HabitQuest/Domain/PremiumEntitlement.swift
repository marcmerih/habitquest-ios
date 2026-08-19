import Foundation

enum PremiumAccessTier: Int, Codable, CaseIterable, Hashable, Comparable, Sendable {
    case free = 0
    case trial = 1
    case premium = 2

    static func < (lhs: PremiumAccessTier, rhs: PremiumAccessTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum PremiumFeature: String, Codable, CaseIterable, Hashable, Sendable {
    case advancedRoutines
    case customDaySections
    case advancedScheduling
    case multipleReminders
    case smartReminders
    case advancedAnalytics
    case longTermAnalytics
    case habitInsights
    case habitReflections
    case advancedWidgets
    case premiumThemes
    case premiumAppIcons
    case advancedCustomization
    case advancedGamification

    var minimumRequiredTier: PremiumAccessTier {
        .trial
    }

    var displayName: String {
        switch self {
        case .advancedRoutines:
            return "Advanced Routines"
        case .customDaySections:
            return "Custom Day Sections"
        case .advancedScheduling:
            return "Advanced Scheduling"
        case .multipleReminders:
            return "Multiple Reminders"
        case .smartReminders:
            return "Smart Reminders"
        case .advancedAnalytics:
            return "Advanced Analytics"
        case .longTermAnalytics:
            return "Long-Term Analytics"
        case .habitInsights:
            return "Habit Insights"
        case .habitReflections:
            return "Habit Reflections"
        case .advancedWidgets:
            return "Advanced Widgets"
        case .premiumThemes:
            return "Premium Themes"
        case .premiumAppIcons:
            return "Premium App Icons"
        case .advancedCustomization:
            return "Advanced Customization"
        case .advancedGamification:
            return "Advanced Gamification"
        }
    }

    func gateDescriptor(
        origin: PremiumGatePresentationOrigin,
        entryPoint: String
    ) -> PremiumFeatureGateDescriptor {
        PremiumFeatureGateDescriptor(
            feature: self,
            headline: gateHeadline,
            explanation: gateExplanation,
            previewSymbolName: gatePreviewSymbolName,
            paywallSourceMetadata: PremiumPaywallSourceMetadata(
                origin: origin,
                entryPoint: entryPoint,
                feature: self
            )
        )
    }

    var gateHeadline: String {
        switch self {
        case .advancedRoutines:
            return "Shape your day around intentional routines."
        case .customDaySections:
            return "Organize HabitQuest the way your day actually feels."
        case .advancedScheduling:
            return "Make more complex scheduling feel simple."
        case .multipleReminders:
            return "Stay supported with flexible follow-ups."
        case .smartReminders:
            return "Let reminders adapt more naturally to your flow."
        case .advancedAnalytics:
            return "Understand the patterns behind your progress."
        case .longTermAnalytics:
            return "See the bigger story in your habits over time."
        case .habitInsights:
            return "Spot the habits that deserve more attention."
        case .habitReflections:
            return "Capture how habits actually felt, not just whether they happened."
        case .advancedWidgets:
            return "Keep HabitQuest close at a glance."
        case .premiumThemes:
            return "Make HabitQuest feel more like your own."
        case .premiumAppIcons:
            return "Personalize the app icon with more taste."
        case .advancedCustomization:
            return "Tune the details so the app fits your rhythm."
        case .advancedGamification:
            return "Make progress feel more expressive and rewarding."
        }
    }

    var gateExplanation: String {
        switch self {
        case .advancedRoutines:
            return "Build richer morning, afternoon, and evening routines that mirror how you live."
        case .customDaySections:
            return "Group habits into sections that make the day easier to read and return to."
        case .advancedScheduling:
            return "Handle more advanced recurrence patterns without turning the app into a form."
        case .multipleReminders:
            return "Use more than one reminder when a habit needs a little extra support."
        case .smartReminders:
            return "Keep reminders calmer, more flexible, and better timed to the habit itself."
        case .advancedAnalytics:
            return "See deeper patterns across completion, rhythm, and consistency."
        case .longTermAnalytics:
            return "Reflect on how your habits have changed across weeks and months."
        case .habitInsights:
            return "Surface the habits that are helping most, and the ones that need attention."
        case .habitReflections:
            return "Add a reflective layer to completions so you can remember how a habit felt."
        case .advancedWidgets:
            return "Bring HabitQuest into your day with more glanceable entry points."
        case .premiumThemes:
            return "Use warmer, more personal themes that make the app feel more like yours."
        case .premiumAppIcons:
            return "Choose from additional app icons with a calmer, premium finish."
        case .advancedCustomization:
            return "Shape HabitQuest around your preferences instead of the other way around."
        case .advancedGamification:
            return "Unlock a richer progression layer while keeping the same calm tone."
        }
    }

    var gatePreviewSymbolName: String? {
        switch self {
        case .advancedRoutines:
            return "calendar.badge.clock"
        case .customDaySections:
            return "square.grid.2x2"
        case .advancedScheduling:
            return "clock.arrow.circlepath"
        case .multipleReminders:
            return "bell.badge"
        case .smartReminders:
            return "bell.and.waves.left.and.right"
        case .advancedAnalytics:
            return "chart.bar.xaxis"
        case .longTermAnalytics:
            return "chart.line.uptrend.xyaxis"
        case .habitInsights:
            return "lightbulb"
        case .habitReflections:
            return "pencil.and.outline"
        case .advancedWidgets:
            return "rectangle.3.group"
        case .premiumThemes:
            return "paintbrush"
        case .premiumAppIcons:
            return "app.badge"
        case .advancedCustomization:
            return "slider.horizontal.3"
        case .advancedGamification:
            return "sparkles.rectangle.stack"
        }
    }

    var analyticsSourceIdentifier: String {
        rawValue.analyticsSourceIdentifier
    }
}

enum PremiumEntitlementStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case revoked
    case expired
    case inGracePeriod
    case inBillingRetry
    case trialing
}

enum PremiumBillingRetryState: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case retrying
    case gracePeriod
}

enum PremiumSubscriptionStatus: Codable, Equatable, Hashable, Sendable {
    case free(isEligibleForIntroOffer: Bool, hadPreviousEntitlement: Bool)
    case activeTrial
    case activePaid

    var isEligibleForIntroOffer: Bool {
        switch self {
        case .free(let isEligibleForIntroOffer, _):
            return isEligibleForIntroOffer
        case .activeTrial, .activePaid:
            return false
        }
    }

    var hadPreviousEntitlement: Bool {
        switch self {
        case .free(_, let hadPreviousEntitlement):
            return hadPreviousEntitlement
        case .activeTrial, .activePaid:
            return true
        }
    }

    var isActiveTrial: Bool {
        if case .activeTrial = self { return true }
        return false
    }

    var isActivePaid: Bool {
        if case .activePaid = self { return true }
        return false
    }
}

struct PremiumProductInfo: Codable, Equatable, Hashable, Sendable {
    var productIdentifier: String
    var displayName: String?
    var displayPrice: String?
    var subscriptionPeriodDescription: String?
    var introductoryOfferDescription: String?
    var subscriptionGroupID: String?
    var subscriptionGroupDisplayName: String?
    var storefrontName: String?
    var price: Decimal?
    var currencyCode: String?

    init(
        productIdentifier: String,
        displayName: String? = nil,
        displayPrice: String? = nil,
        subscriptionPeriodDescription: String? = nil,
        introductoryOfferDescription: String? = nil,
        subscriptionGroupID: String? = nil,
        subscriptionGroupDisplayName: String? = nil,
        storefrontName: String? = nil,
        price: Decimal? = nil,
        currencyCode: String? = nil
    ) {
        self.productIdentifier = productIdentifier
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.subscriptionPeriodDescription = subscriptionPeriodDescription
        self.introductoryOfferDescription = introductoryOfferDescription
        self.subscriptionGroupID = subscriptionGroupID
        self.subscriptionGroupDisplayName = subscriptionGroupDisplayName
        self.storefrontName = storefrontName
        self.price = price
        self.currencyCode = currencyCode
    }
}

enum PremiumGatePresentationOrigin: String, Codable, CaseIterable, Hashable, Sendable {
    case profile
    case today
    case habits
    case analytics
    case settings
    case onboarding
    case custom

    var displayName: String {
        switch self {
        case .profile:
            return "Profile"
        case .today:
            return "Today"
        case .habits:
            return "Habits"
        case .analytics:
            return "Analytics"
        case .settings:
            return "Settings"
        case .onboarding:
            return "Onboarding"
        case .custom:
            return "HabitQuest"
        }
    }
}

struct PremiumPaywallSourceMetadata: Codable, Equatable, Hashable, Sendable {
    var origin: PremiumGatePresentationOrigin
    var entryPoint: String
    var feature: PremiumFeature

    init(
        origin: PremiumGatePresentationOrigin,
        entryPoint: String,
        feature: PremiumFeature
    ) {
        self.origin = origin
        self.entryPoint = entryPoint
        self.feature = feature
    }

    var displayLabel: String {
        "\(origin.displayName) · \(feature.displayName)"
    }

    var analyticsContext: AnalyticsContextMetadata {
        let sourceIdentifier = entryPoint.analyticsSourceIdentifier
        return AnalyticsContextMetadata(
            source: sourceIdentifier == "unknown" ? feature.analyticsSourceIdentifier : sourceIdentifier,
            featureIdentifier: feature.analyticsSourceIdentifier
        )
    }
}

struct PremiumFeatureGateDescriptor: Identifiable, Codable, Equatable, Hashable, Sendable {
    var feature: PremiumFeature
    var headline: String
    var explanation: String
    var previewSymbolName: String?
    var paywallSourceMetadata: PremiumPaywallSourceMetadata

    var id: PremiumFeature { feature }

    var analyticsContext: AnalyticsContextMetadata {
        paywallSourceMetadata.analyticsContext
    }
}

struct PremiumAccessMetadata: Codable, Equatable, Hashable, Sendable {
    var entitlementStatus: PremiumEntitlementStatus?
    var subscriptionExpirationDate: Date?
    var billingRetryState: PremiumBillingRetryState?
    var introductoryOfferEligibility: Bool?
    var subscriptionStatus: PremiumSubscriptionStatus?
    var productInfo: PremiumProductInfo?

    init(
        entitlementStatus: PremiumEntitlementStatus? = nil,
        subscriptionExpirationDate: Date? = nil,
        billingRetryState: PremiumBillingRetryState? = nil,
        introductoryOfferEligibility: Bool? = nil,
        subscriptionStatus: PremiumSubscriptionStatus? = nil,
        productInfo: PremiumProductInfo? = nil
    ) {
        self.entitlementStatus = entitlementStatus
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.billingRetryState = billingRetryState
        self.introductoryOfferEligibility = introductoryOfferEligibility
        self.subscriptionStatus = subscriptionStatus
        self.productInfo = productInfo
    }
}

struct PremiumAccessState: Codable, Equatable, Hashable, Sendable {
    var tier: PremiumAccessTier
    var metadata: PremiumAccessMetadata

    init(tier: PremiumAccessTier, metadata: PremiumAccessMetadata = .init()) {
        self.tier = tier
        self.metadata = metadata
    }

    static let free = PremiumAccessState(tier: .free)
    static let trial = PremiumAccessState(tier: .trial)
    static let premium = PremiumAccessState(tier: .premium)

    var isPremiumOrTrial: Bool {
        tier >= .trial
    }
}

extension PremiumAccessState {
    func canAccess(_ feature: PremiumFeature) -> Bool {
        tier >= feature.minimumRequiredTier
    }

    var subscriptionStatus: PremiumSubscriptionStatus? {
        metadata.subscriptionStatus
    }

    var isEligibleForIntroOffer: Bool {
        metadata.subscriptionStatus?.isEligibleForIntroOffer ?? metadata.introductoryOfferEligibility ?? false
    }
}
