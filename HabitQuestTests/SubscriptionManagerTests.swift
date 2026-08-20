import XCTest
@testable import HabitQuest

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    func testEligibleFreeUserShowsIntroTrialAvailability() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            ),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .premium)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.accessState, .free)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .free(isEligibleForIntroOffer: true, hadPreviousEntitlement: false))
        XCTAssertTrue(entitlementService.isEligibleForIntroOffer)
        XCTAssertEqual(manager.availableProducts.map(\.id), SubscriptionCatalog.allProductIDs)
        XCTAssertEqual(client.loadProductsCallCount, 1)
    }

    func testEmptyProductLoadFallsBackToLocalSubscriptionPlans() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: false
            ),
            products: []
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.availableProducts.map(\.id), SubscriptionCatalog.allProductIDs)
        XCTAssertFalse(manager.availableProducts.isEmpty)
        XCTAssertTrue(manager.availableProducts.allSatisfy { $0.isEligibleForIntroOffer == true })
        XCTAssertNil(manager.lastError)
    }

    func testIneligibleFreeUserUsesStandardSubscriptionLanguage() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: false
            ),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.accessState.subscriptionStatus, .free(isEligibleForIntroOffer: false, hadPreviousEntitlement: false))
        XCTAssertFalse(entitlementService.isEligibleForIntroOffer)
    }

    func testActiveTrialPropagatesToEntitlementService() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activeTrialAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.accessState, .trial)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .activeTrial)
        XCTAssertTrue(entitlementService.canAccess(.advancedAnalytics))
    }

    func testActivePaidPropagatesToEntitlementService() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activePaidAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .activePaid)
        XCTAssertEqual(entitlementService.accessState, .premium)
    }

    func testForegroundRefreshSyncsTrialConversionToPaidSubscription() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activeTrialAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .trial)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        client.accessState = Self.activePaidAccessState()
        await manager.refreshOnForeground()

        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .activePaid)
        XCTAssertEqual(entitlementService.accessState, .premium)
    }

    func testExpiredTrialIsRepresentedAsLapsedAfterPreviousEntitlement() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.lapsedAccessState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: true
            ),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .premium)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.accessState, .free)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .free(isEligibleForIntroOffer: false, hadPreviousEntitlement: true))
        XCTAssertFalse(entitlementService.canAccess(.advancedAnalytics))
    }

    func testPurchaseCancellationDoesNotChangeAccessState() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            ),
            products: Self.products,
            purchaseOutcome: .cancelled
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()
        await manager.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(manager.accessState, .free)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .free(isEligibleForIntroOffer: true, hadPreviousEntitlement: false))
        XCTAssertEqual(entitlementService.accessState, .free)
    }

    func testPurchaseCancellationDoesNotDowngradeActivePremiumAccess() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activePaidAccessState(),
            products: Self.products,
            purchaseOutcome: .cancelled
        )
        let entitlementService = PremiumEntitlementService(accessState: .premium)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()
        await manager.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(entitlementService.accessState, .premium)
    }

    func testSuccessfulPurchaseRefreshesAccessState() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activePaidAccessState(),
            products: Self.products,
            purchaseOutcome: .success
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()
        await manager.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .activePaid)
        XCTAssertEqual(entitlementService.accessState, .premium)
        XCTAssertEqual(client.purchaseCallCount, 1)
    }

    func testPurchaseFlowTracksMonetizationEvents() async {
        let tracker = RecordingAnalyticsTracker()
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            ),
            products: Self.products,
            purchaseOutcome: .success,
            postPurchaseAccessState: Self.activeTrialAccessState()
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(
            client: client,
            entitlementService: entitlementService,
            analyticsTracker: tracker
        )

        await manager.startIfNeeded()
        await manager.purchase(productID: SubscriptionCatalog.monthlyProductID, analyticsContext: AnalyticsContextMetadata(source: "multiple_reminders"))

        XCTAssertEqual(
            tracker.events,
            [
                .premiumPurchaseStarted(AnalyticsContextMetadata(source: "multiple_reminders")),
                .premiumPurchaseCompleted(AnalyticsContextMetadata(source: "multiple_reminders")),
                .premiumTrialStarted(AnalyticsContextMetadata(source: "multiple_reminders"))
            ]
        )
    }

    func testDecliningOfferDoesNotConsumeTrialEligibility() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            ),
            products: Self.products,
            purchaseOutcome: .cancelled
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()
        await manager.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(manager.accessState.subscriptionStatus, .free(isEligibleForIntroOffer: true, hadPreviousEntitlement: false))
        XCTAssertTrue(entitlementService.isEligibleForIntroOffer)
    }

    func testRestorePurchasesReportsSuccessWhenStateChanges() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activePaidAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()
        let result = await manager.restorePurchases()

        XCTAssertEqual(result, .succeeded(message: "Purchases restored."))
        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(entitlementService.accessState, .premium)
    }

    func testRestorePurchasesReportsNoPurchasesFoundWhenNothingRestores() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: false
            ),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()
        let result = await manager.restorePurchases()

        XCTAssertEqual(result, .noPurchasesFound)
        XCTAssertEqual(manager.accessState, .free)
    }

    func testForegroundRefreshSyncsExternalStoreKitChangesWithoutRestart() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: false,
                hadPreviousEntitlement: false
            ),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        client.accessState = Self.activePaidAccessState()
        await manager.refreshOnForeground()

        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(entitlementService.accessState, .premium)
    }

    func testTransactionUpdatesWhileRunningRefreshAccessState() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.freeAccessState(
                isEligibleForIntroOffer: true,
                hadPreviousEntitlement: false
            ),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        client.accessState = Self.activePaidAccessState()
        await client.triggerTransactionUpdate()

        XCTAssertEqual(manager.accessState, .premium)
        XCTAssertEqual(entitlementService.accessState, .premium)
    }

    func testSubscriptionMetadataKeepsBillingRetryStateThroughRefresh() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.billingRetryAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let manager = SubscriptionManager(client: client, entitlementService: entitlementService)

        await manager.startIfNeeded()

        XCTAssertEqual(manager.accessState.metadata.billingRetryState, .retrying)
        XCTAssertEqual(entitlementService.accessState.metadata.billingRetryState, .retrying)
        XCTAssertEqual(manager.accessState.subscriptionStatus, .free(isEligibleForIntroOffer: false, hadPreviousEntitlement: true))
    }

    func testManageSubscriptionUsesPresenterAndSubscriptionGroupID() async {
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activePaidAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .premium)
        let presenter = MockSubscriptionManagementPresenter()
        let manager = SubscriptionManager(
            client: client,
            entitlementService: entitlementService,
            subscriptionManagementPresenter: presenter
        )

        await manager.startIfNeeded()
        let result = await manager.manageSubscription()

        XCTAssertEqual(result, .succeeded(message: "Subscription management opened."))
        XCTAssertEqual(presenter.presentedSubscriptionGroupID, "habitquest.premium")
        XCTAssertEqual(presenter.presentationCount, 1)
    }

    func testMonetizationAnalyticsSourceIdentifiersAreSanitized() {
        XCTAssertEqual("90-day analytics preview".analyticsSourceIdentifier, "90_day_analytics_preview")

        let metadata = PremiumPaywallSourceMetadata(
            origin: .analytics,
            entryPoint: "Multiple reminders",
            feature: .multipleReminders
        )

        XCTAssertEqual(metadata.analyticsContext, AnalyticsContextMetadata(source: "multiple_reminders", featureIdentifier: "multiple_reminders"))
    }

    func testRestoreAndManageSubscriptionTrackMonetizationEvents() async {
        let tracker = RecordingAnalyticsTracker()
        let client = MockSubscriptionStoreKitClient(
            accessState: Self.activePaidAccessState(),
            products: Self.products
        )
        let entitlementService = PremiumEntitlementService(accessState: .free)
        let presenter = MockSubscriptionManagementPresenter()
        let manager = SubscriptionManager(
            client: client,
            entitlementService: entitlementService,
            subscriptionManagementPresenter: presenter,
            analyticsTracker: tracker
        )

        await manager.startIfNeeded()
        _ = await manager.restorePurchases(analyticsContext: AnalyticsContextMetadata(source: "habit_insights"))
        _ = await manager.manageSubscription(analyticsContext: AnalyticsContextMetadata(source: "habit_insights"))

        XCTAssertEqual(
            tracker.events,
            [
                .premiumRestoreStarted(AnalyticsContextMetadata(source: "habit_insights")),
                .premiumRestoreCompleted(AnalyticsContextMetadata(source: "habit_insights")),
                .premiumManageSubscriptionOpened(AnalyticsContextMetadata(source: "habit_insights"))
            ]
        )
    }

    func testStoreKitFixtureScenariosAreDeterministicAndUsable() async {
        for scenario in HabitQuestPremiumStoreKitScenario.allCases {
            let fixture = HabitQuestStoreKitFixtureFactory.fixture(for: scenario)

            await fixture.subscriptionManager.startIfNeeded()

            XCTAssertEqual(fixture.subscriptionManager.availableProducts.map(\.id), SubscriptionCatalog.allProductIDs, scenario.displayName)
            XCTAssertEqual(fixture.subscriptionManager.accessState, scenario.accessState, scenario.displayName)
            XCTAssertEqual(fixture.entitlementService.accessState, scenario.accessState, scenario.displayName)
            XCTAssertEqual(fixture.client.loadProductsCallCount, 1, scenario.displayName)
            XCTAssertEqual(fixture.client.refreshAccessStateCallCount, 1, scenario.displayName)

            if let selection = scenario.premiumSelection {
                XCTAssertEqual(fixture.personalizationStore.selection, selection, scenario.displayName)
            } else {
                XCTAssertEqual(fixture.personalizationStore.selection, .default, scenario.displayName)
            }
        }
    }

    func testStoreKitFixtureSupportsLiveUpdatesAndPreservedPremiumConfiguration() async {
        let updateFixture = HabitQuestStoreKitFixtureFactory.fixture(for: .entitlementUpdateWhileAppIsRunning)

        await updateFixture.subscriptionManager.startIfNeeded()
        await updateFixture.client.simulateTransactionUpdate(to: .premium)

        XCTAssertEqual(updateFixture.subscriptionManager.accessState, .premium)
        XCTAssertEqual(updateFixture.entitlementService.accessState, .premium)

        let preservedFixture = HabitQuestStoreKitFixtureFactory.fixture(for: .premiumFreePremiumWithPreservedConfiguration)
        let premiumSelection = preservedFixture.personalizationStore.selection

        XCTAssertEqual(premiumSelection.themeVariant, .ember)
        XCTAssertEqual(premiumSelection.accentPalette, .sage)
        XCTAssertEqual(premiumSelection.appIcon, .dusk)

        preservedFixture.entitlementService.update(accessState: .free)
        XCTAssertEqual(preservedFixture.personalizationStore.selection, premiumSelection)
        XCTAssertEqual(preservedFixture.personalizationStore.effectiveSelection.themeVariant, .standard)

        preservedFixture.entitlementService.update(accessState: .premium)
        XCTAssertEqual(preservedFixture.personalizationStore.effectiveSelection, premiumSelection)
    }

#if canImport(StoreKitTest)
    func testStoreKitHarnessCanFindTheLocalConfigurationFile() throws {
        guard let configurationURL = HabitQuestStoreKitTestSessionHarness.defaultConfigurationURL() else {
            throw XCTSkip("HabitQuestPremium.storekit has not been created yet.")
        }

        _ = try HabitQuestStoreKitTestSessionHarness(configurationFileURL: configurationURL)
    }
#endif

    private static let products: [SubscriptionProduct] = [
        SubscriptionProduct(
            id: SubscriptionCatalog.monthlyProductID,
            displayName: "HabitQuest Premium Monthly",
            displayPrice: "$6.99",
            subscriptionPeriodDescription: "1 month",
            introductoryOfferDescription: "Free trial",
            subscriptionGroupID: "habitquest.premium",
            subscriptionGroupDisplayName: "HabitQuest Premium"
        ),
        SubscriptionProduct(
            id: SubscriptionCatalog.annualProductID,
            displayName: "HabitQuest Premium Annual",
            displayPrice: "$59.99",
            subscriptionPeriodDescription: "1 year",
            introductoryOfferDescription: "Free trial",
            subscriptionGroupID: "habitquest.premium",
            subscriptionGroupDisplayName: "HabitQuest Premium"
        )
    ]

    private static func freeAccessState(
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

    private static func activeTrialAccessState() -> PremiumAccessState {
        PremiumAccessState(
            tier: .trial,
            metadata: PremiumAccessMetadata(
                entitlementStatus: .trialing,
                introductoryOfferEligibility: true,
                subscriptionStatus: .activeTrial
            )
        )
    }

    private static func activePaidAccessState() -> PremiumAccessState {
        PremiumAccessState(
            tier: .premium,
            metadata: PremiumAccessMetadata(
                entitlementStatus: .active,
                introductoryOfferEligibility: false,
                subscriptionStatus: .activePaid
            )
        )
    }

    private static func lapsedAccessState(
        isEligibleForIntroOffer: Bool,
        hadPreviousEntitlement: Bool
    ) -> PremiumAccessState {
        freeAccessState(
            isEligibleForIntroOffer: isEligibleForIntroOffer,
            hadPreviousEntitlement: hadPreviousEntitlement
        )
    }

    private static func billingRetryAccessState() -> PremiumAccessState {
        PremiumAccessState(
            tier: .free,
            metadata: PremiumAccessMetadata(
                entitlementStatus: .inBillingRetry,
                billingRetryState: .retrying,
                introductoryOfferEligibility: false,
                subscriptionStatus: .free(
                    isEligibleForIntroOffer: false,
                    hadPreviousEntitlement: true
                )
            )
        )
    }
}

private final class MockSubscriptionStoreKitClient: SubscriptionStoreKitClient, @unchecked Sendable {
    var accessState: PremiumAccessState
    let products: [SubscriptionProduct]
    var purchaseOutcome: SubscriptionPurchaseOutcome
    var postPurchaseAccessState: PremiumAccessState?
    var restoredAccessState: PremiumAccessState?
    private(set) var loadProductsCallCount = 0
    private(set) var refreshAccessStateCallCount = 0
    private(set) var purchaseCallCount = 0
    private var transactionUpdateHandler: (@Sendable () async -> Void)?

    init(
        accessState: PremiumAccessState,
        products: [SubscriptionProduct],
        purchaseOutcome: SubscriptionPurchaseOutcome = .success,
        postPurchaseAccessState: PremiumAccessState? = nil,
        restoredAccessState: PremiumAccessState? = nil
    ) {
        self.accessState = accessState
        self.products = products
        self.purchaseOutcome = purchaseOutcome
        self.postPurchaseAccessState = postPurchaseAccessState
        self.restoredAccessState = restoredAccessState
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
        return SubscriptionUpdateObservation(cancellation: {})
    }

    func triggerTransactionUpdate() async {
        await transactionUpdateHandler?()
    }
}

private final class MockSubscriptionManagementPresenter: SubscriptionManagementPresenting, @unchecked Sendable {
    private(set) var presentedSubscriptionGroupID: String?
    private(set) var presentationCount = 0

    @MainActor
    func presentManageSubscription(subscriptionGroupID: String?) async throws {
        presentationCount += 1
        presentedSubscriptionGroupID = subscriptionGroupID
    }
}

private final class RecordingAnalyticsTracker: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

#if canImport(StoreKitTest)
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
        guard let transactionIdentifier = session.allTransactions().last(where: { $0.productIdentifier == productID })?.identifier else {
            throw NSError(domain: "HabitQuestStoreKitTestSessionHarness", code: 2, userInfo: [NSLocalizedDescriptionKey: "No transaction found for product identifier \(productID)."])
        }

        try session.disableAutoRenewForTransaction(identifier: transactionIdentifier)
    }

    func enableAutoRenew(for productID: String) throws {
        guard let transactionIdentifier = session.allTransactions().last(where: { $0.productIdentifier == productID })?.identifier else {
            throw NSError(domain: "HabitQuestStoreKitTestSessionHarness", code: 3, userInfo: [NSLocalizedDescriptionKey: "No transaction found for product identifier \(productID)."])
        }

        try session.enableAutoRenewForTransaction(identifier: transactionIdentifier)
    }

    func buy(_ productID: String) async throws {
        _ = try await session.buyProduct(identifier: productID, options: [])
    }

    func clearTransactions() {
        session.clearTransactions()
    }
}
#endif
