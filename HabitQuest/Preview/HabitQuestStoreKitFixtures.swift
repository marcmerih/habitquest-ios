import Foundation

enum HabitQuestPremiumStoreKitScenario: String, CaseIterable, Identifiable, Sendable {
    case freeEligibleForTrial
    case freeAfterDecliningAutomaticTrialIntro
    case activeSevenDayTrial
    case trialExpired
    case freeNoLongerTrialEligible
    case monthlyPremiumSubscriber
    case annualPremiumSubscriber
    case subscriptionCanceledButStillActive
    case expiredSubscription
    case restoredSubscription
    case purchaseCancellation
    case purchaseFailure
    case successfulPurchase
    case entitlementUpdateWhileAppIsRunning
    case premiumToFreeTransition
    case freeToPremiumTransition
    case premiumFreePremiumWithPreservedConfiguration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freeEligibleForTrial:
            return "Free Eligible For Trial"
        case .freeAfterDecliningAutomaticTrialIntro:
            return "Free After Declining Intro"
        case .activeSevenDayTrial:
            return "Active Seven-Day Trial"
        case .trialExpired:
            return "Trial Expired"
        case .freeNoLongerTrialEligible:
            return "Free No Longer Trial Eligible"
        case .monthlyPremiumSubscriber:
            return "Monthly Premium Subscriber"
        case .annualPremiumSubscriber:
            return "Annual Premium Subscriber"
        case .subscriptionCanceledButStillActive:
            return "Canceled But Still Active"
        case .expiredSubscription:
            return "Expired Subscription"
        case .restoredSubscription:
            return "Restored Subscription"
        case .purchaseCancellation:
            return "Purchase Cancellation"
        case .purchaseFailure:
            return "Purchase Failure"
        case .successfulPurchase:
            return "Successful Purchase"
        case .entitlementUpdateWhileAppIsRunning:
            return "Live Entitlement Update"
        case .premiumToFreeTransition:
            return "Premium To Free"
        case .freeToPremiumTransition:
            return "Free To Premium"
        case .premiumFreePremiumWithPreservedConfiguration:
            return "Premium Free Premium With Preserved Configuration"
        }
    }

    var summary: String {
        switch self {
        case .freeEligibleForTrial:
            return "Free user eligible for the StoreKit introductory offer."
        case .freeAfterDecliningAutomaticTrialIntro:
            return "Free user who declined the automatic Premium introduction but remains eligible in StoreKit."
        case .activeSevenDayTrial:
            return "Active Premium trial with trial UI and premium access."
        case .trialExpired:
            return "Trial expired and entitlement returned to Free."
        case .freeNoLongerTrialEligible:
            return "Free user with no remaining introductory-offer eligibility."
        case .monthlyPremiumSubscriber:
            return "Active monthly Premium entitlement."
        case .annualPremiumSubscriber:
            return "Active annual Premium entitlement."
        case .subscriptionCanceledButStillActive:
            return "Subscription canceled in Apple settings but entitlement remains active until the end date."
        case .expiredSubscription:
            return "Subscription expired and only preserved premium data remains."
        case .restoredSubscription:
            return "Restored subscription after a previous free state."
        case .purchaseCancellation:
            return "Purchase was canceled and access stays unchanged."
        case .purchaseFailure:
            return "Purchase failed and access stays unchanged."
        case .successfulPurchase:
            return "Purchase succeeds and Premium becomes active."
        case .entitlementUpdateWhileAppIsRunning:
            return "A live StoreKit change arrives while the app is running."
        case .premiumToFreeTransition:
            return "Premium entitlement falls back to Free without losing stored data."
        case .freeToPremiumTransition:
            return "Free user regains Premium access."
        case .premiumFreePremiumWithPreservedConfiguration:
            return "Premium configuration survives a downgrade and becomes available again after resubscription."
        }
    }

    var accessState: PremiumAccessState {
        switch self {
        case .freeEligibleForTrial:
            return Self.freeState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            )
        case .freeAfterDecliningAutomaticTrialIntro:
            return Self.freeState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            )
        case .activeSevenDayTrial:
            return Self.trialState()
        case .trialExpired:
            return Self.freeState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: true
            )
        case .freeNoLongerTrialEligible:
            return Self.freeState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: false
            )
        case .monthlyPremiumSubscriber:
            return Self.premiumState(productID: SubscriptionCatalog.monthlyProductID)
        case .annualPremiumSubscriber:
            return Self.premiumState(productID: SubscriptionCatalog.annualProductID)
        case .subscriptionCanceledButStillActive:
            return PremiumAccessState(
                tier: .premium,
                metadata: PremiumAccessMetadata(
                    entitlementStatus: .active,
                    subscriptionExpirationDate: Self.referenceDate.addingTimeInterval(86_400 * 14),
                    billingRetryState: PremiumBillingRetryState.none,
                    introductoryOfferEligibility: false,
                    subscriptionStatus: .activePaid,
                    productInfo: PremiumProductInfo(
                        productIdentifier: SubscriptionCatalog.monthlyProductID,
                        displayName: "HabitQuest Premium Monthly",
                        displayPrice: "$6.99",
                        subscriptionPeriodDescription: "1 month",
                        introductoryOfferDescription: "7-day free trial",
                        subscriptionGroupID: "habitquest.premium",
                        subscriptionGroupDisplayName: "HabitQuest Premium"
                    )
                )
            )
        case .expiredSubscription:
            return Self.freeState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: true
            )
        case .restoredSubscription:
            return Self.premiumState(productID: SubscriptionCatalog.monthlyProductID)
        case .purchaseCancellation:
            return Self.freeState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            )
        case .purchaseFailure:
            return Self.freeState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            )
        case .successfulPurchase:
            return Self.premiumState(productID: SubscriptionCatalog.monthlyProductID)
        case .entitlementUpdateWhileAppIsRunning:
            return Self.freeState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            )
        case .premiumToFreeTransition:
            return Self.freeState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: true
            )
        case .freeToPremiumTransition:
            return Self.premiumState(productID: SubscriptionCatalog.annualProductID)
        case .premiumFreePremiumWithPreservedConfiguration:
            return Self.freeState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: true
            )
        }
    }

    var purchaseOutcome: SubscriptionPurchaseOutcome {
        switch self {
        case .purchaseCancellation:
            return .cancelled
        case .purchaseFailure:
            return .pending
        default:
            return .success
        }
    }

    var restoredAccessState: PremiumAccessState? {
        switch self {
        case .restoredSubscription, .successfulPurchase, .freeToPremiumTransition, .entitlementUpdateWhileAppIsRunning:
            return .premium
        default:
            return nil
        }
    }

    var postPurchaseAccessState: PremiumAccessState? {
        switch self {
        case .successfulPurchase:
            return Self.premiumState(productID: SubscriptionCatalog.monthlyProductID)
        case .activeSevenDayTrial:
            return Self.trialState()
        default:
            return nil
        }
    }

    var premiumSelection: HabitQuestPersonalizationSelection? {
        guard self == .premiumFreePremiumWithPreservedConfiguration else {
            return nil
        }

        return HabitQuestPersonalizationSelection(
            themeVariant: .ember,
            accentPalette: .sage,
            cardAppearance: .glassier,
            completionEffectStyle: .orbital,
            hapticStyle: .expressive,
            soundStyle: .glass,
            progressionCosmeticStyle: .orb,
            appIcon: .dusk
        )
    }

    private static func freeState(
        isEligibleForIntroOffer: Bool,
        hadPreviousEntitlement: Bool
    ) -> PremiumAccessState {
        PremiumAccessState(
            tier: .free,
            metadata: PremiumAccessMetadata(
                entitlementStatus: hadPreviousEntitlement ? .expired : nil,
                introductoryOfferEligibility: isEligibleForIntroOffer,
                subscriptionStatus: .free(
                    isEligibleForIntroOffer: isEligibleForIntroOffer,
                    hadPreviousEntitlement: hadPreviousEntitlement
                )
            )
        )
    }

    private static func trialState() -> PremiumAccessState {
        PremiumAccessState(
            tier: .trial,
            metadata: PremiumAccessMetadata(
                entitlementStatus: .trialing,
                subscriptionExpirationDate: Self.referenceDate.addingTimeInterval(86_400 * 7),
                billingRetryState: PremiumBillingRetryState.none,
                introductoryOfferEligibility: true,
                subscriptionStatus: .activeTrial,
                productInfo: PremiumProductInfo(
                    productIdentifier: SubscriptionCatalog.monthlyProductID,
                    displayName: "HabitQuest Premium Monthly",
                    displayPrice: "$6.99",
                    subscriptionPeriodDescription: "1 month",
                    introductoryOfferDescription: "7-day free trial",
                    subscriptionGroupID: "habitquest.premium",
                    subscriptionGroupDisplayName: "HabitQuest Premium"
                )
            )
        )
    }

    private static func premiumState(productID: String) -> PremiumAccessState {
        PremiumAccessState(
            tier: .premium,
            metadata: PremiumAccessMetadata(
                entitlementStatus: .active,
                subscriptionExpirationDate: Self.referenceDate.addingTimeInterval(86_400 * 30),
                billingRetryState: PremiumBillingRetryState.none,
                introductoryOfferEligibility: false,
                subscriptionStatus: .activePaid,
                productInfo: PremiumProductInfo(
                    productIdentifier: productID,
                    displayName: productID == SubscriptionCatalog.annualProductID ? "HabitQuest Premium Annual" : "HabitQuest Premium Monthly",
                    displayPrice: productID == SubscriptionCatalog.annualProductID ? "$59.99" : "$6.99",
                    subscriptionPeriodDescription: productID == SubscriptionCatalog.annualProductID ? "1 year" : "1 month",
                    introductoryOfferDescription: "7-day free trial",
                    subscriptionGroupID: "habitquest.premium",
                    subscriptionGroupDisplayName: "HabitQuest Premium"
                )
            )
        )
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_777_000_000)
}

struct HabitQuestStoreKitFixture {
    let scenario: HabitQuestPremiumStoreKitScenario
    let subscriptionManager: SubscriptionManager
    let entitlementService: PremiumEntitlementService
    let client: HabitQuestStoreKitScenarioClient
    let personalizationStore: HabitQuestPersonalizationStore
}

final class HabitQuestStoreKitScenarioClient: SubscriptionStoreKitClient, @unchecked Sendable {
    private(set) var accessState: PremiumAccessState
    private let products: [SubscriptionProduct]
    private let purchaseOutcome: SubscriptionPurchaseOutcome
    private let restoredAccessState: PremiumAccessState?
    private let postPurchaseAccessState: PremiumAccessState?
    private var transactionUpdateHandler: (@Sendable () async -> Void)?

    private(set) var loadProductsCallCount = 0
    private(set) var refreshAccessStateCallCount = 0
    private(set) var purchaseCallCount = 0

    init(
        accessState: PremiumAccessState,
        products: [SubscriptionProduct],
        purchaseOutcome: SubscriptionPurchaseOutcome = .success,
        restoredAccessState: PremiumAccessState? = nil,
        postPurchaseAccessState: PremiumAccessState? = nil
    ) {
        self.accessState = accessState
        self.products = products
        self.purchaseOutcome = purchaseOutcome
        self.restoredAccessState = restoredAccessState
        self.postPurchaseAccessState = postPurchaseAccessState
    }

    func loadProducts() async throws -> [SubscriptionProduct] {
        loadProductsCallCount += 1
        return products
    }

    func refreshAccessState() async throws -> PremiumAccessState {
        refreshAccessStateCallCount += 1
        return accessState
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        purchaseCallCount += 1
        guard products.contains(where: { $0.id == productID }) else {
            throw SubscriptionManagerError.unknownProduct(productID)
        }

        switch purchaseOutcome {
        case .success:
            accessState = postPurchaseAccessState ?? .premium
            return .success
        case .cancelled:
            return .cancelled
        case .pending:
            return .pending
        }
    }

    func restorePurchases() async throws {
        accessState = restoredAccessState ?? .premium
    }

    func observeTransactionUpdates(onUpdate: @escaping @Sendable () async -> Void) -> SubscriptionUpdateObservation {
        transactionUpdateHandler = onUpdate
        return SubscriptionUpdateObservation(cancellation: { })
    }

    func simulateTransactionUpdate(to newState: PremiumAccessState) async {
        accessState = newState
        await transactionUpdateHandler?()
    }
}

enum HabitQuestStoreKitFixtureFactory {
    static func fixture(for scenario: HabitQuestPremiumStoreKitScenario) -> HabitQuestStoreKitFixture {
        let personalizationStore = HabitQuestPersonalizationStore(
            userDefaults: UserDefaults(suiteName: "habitquest.storekit.fixture.\(scenario.rawValue)") ?? .standard,
            accessState: scenario.accessState
        )

        if let selection = scenario.premiumSelection {
            personalizationStore.updateThemeVariant(selection.themeVariant)
            personalizationStore.updateAccentPalette(selection.accentPalette)
            personalizationStore.updateCardAppearance(selection.cardAppearance)
            personalizationStore.updateCompletionEffectStyle(selection.completionEffectStyle)
            personalizationStore.updateHapticStyle(selection.hapticStyle)
            personalizationStore.updateSoundStyle(selection.soundStyle)
            personalizationStore.updateProgressionCosmeticStyle(selection.progressionCosmeticStyle)
            personalizationStore.updateAppIcon(selection.appIcon)
        }

        let entitlementService = PremiumEntitlementService(
            accessState: scenario.accessState,
            personalizationStore: personalizationStore,
            widgetSnapshotStore: HabitQuestWidgetSnapshotStore(
                userDefaults: UserDefaults(suiteName: "habitquest.storekit.fixture.widgets.\(scenario.rawValue)") ?? .standard
            )
        )

        let client = HabitQuestStoreKitScenarioClient(
            accessState: scenario.accessState,
            products: subscriptionProducts(),
            purchaseOutcome: scenario.purchaseOutcome,
            restoredAccessState: scenario.restoredAccessState,
            postPurchaseAccessState: scenario.postPurchaseAccessState
        )

        let subscriptionManager = SubscriptionManager(
            client: client,
            entitlementService: entitlementService
        )

        return HabitQuestStoreKitFixture(
            scenario: scenario,
            subscriptionManager: subscriptionManager,
            entitlementService: entitlementService,
            client: client,
            personalizationStore: personalizationStore
        )
    }

    static func subscriptionProducts() -> [SubscriptionProduct] {
        [
            SubscriptionProduct(
                id: SubscriptionCatalog.monthlyProductID,
                displayName: "HabitQuest Premium Monthly",
                displayPrice: "$6.99",
                subscriptionPeriodDescription: "1 month",
                introductoryOfferDescription: "7-day free trial",
                subscriptionGroupID: "habitquest.premium",
                subscriptionGroupDisplayName: "HabitQuest Premium",
                storefrontName: "United States",
                isEligibleForIntroOffer: true
            ),
            SubscriptionProduct(
                id: SubscriptionCatalog.annualProductID,
                displayName: "HabitQuest Premium Annual",
                displayPrice: "$59.99",
                subscriptionPeriodDescription: "1 year",
                introductoryOfferDescription: "7-day free trial",
                subscriptionGroupID: "habitquest.premium",
                subscriptionGroupDisplayName: "HabitQuest Premium",
                storefrontName: "United States",
                isEligibleForIntroOffer: true
            )
        ]
    }
}

#if DEBUG && canImport(StoreKitTest)
import StoreKitTest

final class HabitQuestStoreKitTestSessionHarness {
    let session: SKTestSession

    init(configurationFileURL: URL? = HabitQuestStoreKitTestSessionHarness.defaultConfigurationURL()) throws {
        guard let configurationFileURL else {
            throw NSError(domain: "HabitQuestStoreKitTestSessionHarness", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing StoreKit configuration file."])
        }

        session = try SKTestSession(contentsOf: configurationFileURL)
        session.disableDialogs = true
        session.resetToDefaultState()
    }

    static func defaultConfigurationURL() -> URL? {
        let candidateRoots: [URL] = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        ]

        for root in candidateRoots {
            let configurationURL = root.appendingPathComponent("HabitQuestPremium.storekit", isDirectory: false)
            if FileManager.default.fileExists(atPath: configurationURL.path) {
                return configurationURL
            }
        }

        return nil
    }

    func reset() {
        session.resetToDefaultState()
        session.clearTransactions()
    }

    func expireSubscription(_ productID: String) throws {
        try session.expireSubscription(productIdentifier: productID)
    }

    func forceRenewal(_ productID: String) throws {
        try session.forceRenewalOfSubscription(productIdentifier: productID)
    }

    func disableAutoRenew(for productID: String) throws {
        try session.disableAutoRenewForTransaction(productIdentifier: productID)
    }

    func enableAutoRenew(for productID: String) throws {
        try session.enableAutoRenewForTransaction(productIdentifier: productID)
    }

    func buy(_ productID: String) throws {
        try session.buyProduct(identifier: productID)
    }

    func clearTransactions() {
        session.clearTransactions()
    }
}
#endif
