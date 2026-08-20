import Foundation
import StoreKit
import SwiftUI
import UIKit

struct SubscriptionProduct: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let subscriptionPeriodDescription: String?
    let introductoryOfferDescription: String?
    let subscriptionGroupID: String?
    let subscriptionGroupDisplayName: String?
    let storefrontName: String?
    let isEligibleForIntroOffer: Bool?

    init(
        id: String,
        displayName: String,
        displayPrice: String,
        subscriptionPeriodDescription: String?,
        introductoryOfferDescription: String?,
        subscriptionGroupID: String? = nil,
        subscriptionGroupDisplayName: String?,
        storefrontName: String? = nil,
        isEligibleForIntroOffer: Bool? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.subscriptionPeriodDescription = subscriptionPeriodDescription
        self.introductoryOfferDescription = introductoryOfferDescription
        self.subscriptionGroupID = subscriptionGroupID
        self.subscriptionGroupDisplayName = subscriptionGroupDisplayName
        self.storefrontName = storefrontName
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
    }

    var premiumProductInfo: PremiumProductInfo {
        PremiumProductInfo(
            productIdentifier: id,
            displayName: displayName,
            displayPrice: displayPrice,
            subscriptionPeriodDescription: subscriptionPeriodDescription,
            introductoryOfferDescription: introductoryOfferDescription,
            subscriptionGroupID: subscriptionGroupID,
            subscriptionGroupDisplayName: subscriptionGroupDisplayName,
            storefrontName: storefrontName
        )
    }
}

enum SubscriptionPurchaseOutcome: Sendable, Equatable {
    case success
    case cancelled
    case pending
}

enum SubscriptionActionResult: Sendable, Equatable {
    case succeeded(message: String? = nil)
    case cancelled
    case noPurchasesFound
    case failed(SubscriptionManagerError)

    var userMessage: String? {
        switch self {
        case .succeeded(let message):
            return message
        case .cancelled:
            return "The action was cancelled."
        case .noPurchasesFound:
            return "No previous purchases were found to restore."
        case .failed(let error):
            return error.errorDescription
        }
    }
}

enum SubscriptionManagerError: LocalizedError, Equatable, Sendable {
    case productLoadFailed
    case accessRefreshFailed
    case purchaseFailed
    case restoreFailed
    case subscriptionManagementFailed
    case unknownProduct(String)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productLoadFailed:
            return "HabitQuest could not load subscription details."
        case .accessRefreshFailed:
            return "HabitQuest could not refresh subscription access."
        case .purchaseFailed:
            return "HabitQuest could not complete the purchase."
        case .restoreFailed:
            return "HabitQuest could not restore purchases."
        case .subscriptionManagementFailed:
            return "HabitQuest could not open subscription management."
        case .unknownProduct:
            return "That subscription product is not available."
        case .verificationFailed:
            return "HabitQuest could not verify the subscription transaction."
        }
    }
}

protocol SubscriptionManagementPresenting: Sendable {
    @MainActor
    func presentManageSubscription(subscriptionGroupID: String?) async throws
}

struct LiveSubscriptionManagementPresenter: SubscriptionManagementPresenting {
    @MainActor
    func presentManageSubscription(subscriptionGroupID: String?) async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw SubscriptionManagerError.subscriptionManagementFailed
        }

        if let subscriptionGroupID {
            try await AppStore.showManageSubscriptions(in: scene, subscriptionGroupID: subscriptionGroupID)
        } else {
            try await AppStore.showManageSubscriptions(in: scene)
        }
    }
}

protocol SubscriptionStoreKitClient: AnyObject, Sendable {
    func loadProducts() async throws -> [SubscriptionProduct]
    func refreshAccessState() async throws -> PremiumAccessState
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws
    func observeTransactionUpdates(onUpdate: @escaping @Sendable () async -> Void) -> SubscriptionUpdateObservation
}

final class SubscriptionUpdateObservation {
    private let cancellation: @Sendable () -> Void

    init(cancellation: @escaping @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation()
    }
}

final class SubscriptionManager: ObservableObject, @unchecked Sendable {
    @Published private(set) var availableProducts: [SubscriptionProduct] = []
    @Published private(set) var accessState: PremiumAccessState = .free
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRefreshingAccess = false
    @Published private(set) var isPurchasingProductID: String?
    @Published private(set) var lastError: SubscriptionManagerError?
    @Published private(set) var lastUpdatedAt: Date?

    private let client: any SubscriptionStoreKitClient
    private let entitlementService: PremiumEntitlementService
    private let subscriptionManagementPresenter: any SubscriptionManagementPresenting
    private let analyticsTracker: any AnalyticsTracking
    private var transactionObservation: SubscriptionUpdateObservation?
    private var didStart = false

    init(
        client: any SubscriptionStoreKitClient,
        entitlementService: PremiumEntitlementService,
        subscriptionManagementPresenter: any SubscriptionManagementPresenting = LiveSubscriptionManagementPresenter(),
        analyticsTracker: any AnalyticsTracking = NoOpAnalyticsTracker()
    ) {
        self.client = client
        self.entitlementService = entitlementService
        self.subscriptionManagementPresenter = subscriptionManagementPresenter
        self.analyticsTracker = analyticsTracker
        self.accessState = entitlementService.accessState
    }

    deinit {
        transactionObservation?.cancel()
    }

    @MainActor
    func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        transactionObservation = client.observeTransactionUpdates { [weak self] in
            await self?.refreshAccessState()
        }

        await refreshProducts()
        await refreshAccessState()
    }

    @MainActor
    func refreshProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await client.loadProducts().sorted {
                SubscriptionCatalog.sortOrder(for: $0.id) < SubscriptionCatalog.sortOrder(for: $1.id)
            }
            availableProducts = products.isEmpty ? SubscriptionCatalog.fallbackProducts() : products
            lastError = nil
        } catch {
            availableProducts = SubscriptionCatalog.fallbackProducts()
            lastError = nil
        }
    }

    @MainActor
    func refreshAccessState() async {
        _ = await refreshSubscriptionStatus()
    }

    @MainActor
    func purchase(productID: String, analyticsContext: AnalyticsContextMetadata? = nil) async {
        isPurchasingProductID = productID
        defer { isPurchasingProductID = nil }

        let context = analyticsContext ?? AnalyticsContextMetadata(source: "subscription_manager")
        analyticsTracker.track(.premiumPurchaseStarted(context))

        do {
            let outcome = try await client.purchase(productID: productID)
            switch outcome {
            case .success:
                await refreshAccessState()
                if accessState.subscriptionStatus?.isActiveTrial == true {
                    analyticsTracker.track(.premiumTrialStarted(context))
                }
                analyticsTracker.track(.premiumPurchaseCompleted(context))
            case .pending:
                lastError = nil
            case .cancelled:
                lastError = nil
                analyticsTracker.track(.premiumPurchaseCancelled(context))
            }
        } catch {
            lastError = .purchaseFailed
        }
    }

    @MainActor
    func restorePurchases(analyticsContext: AnalyticsContextMetadata? = nil) async -> SubscriptionActionResult {
        let previousState = accessState
        let context = analyticsContext ?? AnalyticsContextMetadata(source: "subscription_manager")
        analyticsTracker.track(.premiumRestoreStarted(context))

        do {
            try await client.restorePurchases()
            let refreshResult = await refreshSubscriptionStatus()

            switch refreshResult {
            case .succeeded:
                analyticsTracker.track(.premiumRestoreCompleted(context))
                if previousState.tier == .free, accessState.tier == .free {
                    return .noPurchasesFound
                }

                return .succeeded(message: "Purchases restored.")
            case .cancelled:
                return .cancelled
            case .noPurchasesFound:
                return .noPurchasesFound
            case .failed(let error):
                return .failed(error)
            }
        } catch {
            lastError = .restoreFailed
            return .failed(.restoreFailed)
        }
    }

    @MainActor
    func manageSubscription(analyticsContext: AnalyticsContextMetadata? = nil) async -> SubscriptionActionResult {
        let groupID = accessState.metadata.productInfo?.subscriptionGroupID ?? availableProducts.first?.subscriptionGroupID
        let context = analyticsContext ?? AnalyticsContextMetadata(source: "subscription_manager")

        do {
            try await subscriptionManagementPresenter.presentManageSubscription(subscriptionGroupID: groupID)
            lastError = nil
            analyticsTracker.track(.premiumManageSubscriptionOpened(context))
            return .succeeded(message: "Subscription management opened.")
        } catch is CancellationError {
            lastError = nil
            return .cancelled
        } catch let error as SubscriptionManagerError {
            lastError = error
            return .failed(error)
        } catch {
            lastError = .subscriptionManagementFailed
            return .failed(.subscriptionManagementFailed)
        }
    }

    @MainActor
    func refreshSubscriptionStatus() async -> SubscriptionActionResult {
        isRefreshingAccess = true
        defer { isRefreshingAccess = false }

        do {
            let state = try await client.refreshAccessState()
            guard state != accessState else {
                lastError = nil
                return .succeeded(message: "Subscription status refreshed.")
            }
            apply(accessState: state)
            lastError = nil
            return .succeeded(message: "Subscription status refreshed.")
        } catch {
            lastError = .accessRefreshFailed
            return .failed(.accessRefreshFailed)
        }
    }

    @MainActor
    func refreshOnForeground() async {
        _ = await refreshSubscriptionStatus()
    }

    @MainActor
    private func apply(accessState: PremiumAccessState) {
        self.accessState = accessState
        self.lastUpdatedAt = Date()
        entitlementService.update(accessState: accessState)
    }
}

final class LiveStoreKitSubscriptionClient: SubscriptionStoreKitClient, @unchecked Sendable {
    private var cachedProducts: [String: SubscriptionProduct] = [:]
    private var updateTask: Task<Void, Never>?
    private var usesFallbackCatalog = false
    #if DEBUG
    private var developmentAccessState: PremiumAccessState?
    #endif

    func loadProducts() async throws -> [SubscriptionProduct] {
        do {
            let products = try await Product.products(for: SubscriptionCatalog.allProductIDs)
            var mapped: [SubscriptionProduct] = []
            mapped.reserveCapacity(products.count)

            for product in products {
                if let mappedProduct = await Self.mapProduct(product) {
                    mapped.append(mappedProduct)
                }
            }

            if mapped.isEmpty {
                let fallback = SubscriptionCatalog.fallbackProducts()
                cachedProducts = Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) })
                usesFallbackCatalog = true
                return fallback.sorted {
                    SubscriptionCatalog.sortOrder(for: $0.id) < SubscriptionCatalog.sortOrder(for: $1.id)
                }
            }

            cachedProducts = Dictionary(uniqueKeysWithValues: mapped.map { ($0.id, $0) })
            usesFallbackCatalog = false
            return mapped.sorted {
                SubscriptionCatalog.sortOrder(for: $0.id) < SubscriptionCatalog.sortOrder(for: $1.id)
            }
        } catch {
            let fallback = SubscriptionCatalog.fallbackProducts()
            cachedProducts = Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) })
            usesFallbackCatalog = true
            return fallback.sorted {
                SubscriptionCatalog.sortOrder(for: $0.id) < SubscriptionCatalog.sortOrder(for: $1.id)
            }
        }
    }

    func refreshAccessState() async throws -> PremiumAccessState {
        #if DEBUG
        if usesFallbackCatalog, let developmentAccessState {
            return developmentAccessState
        }
        #endif

        if cachedProducts.isEmpty {
            _ = try await loadProducts()
        }

        let groupID = cachedProducts.values.compactMap(\.subscriptionGroupID).first
        let statuses: [Product.SubscriptionInfo.Status]
        do {
            statuses = try await subscriptionStatuses(for: groupID)
        } catch {
            statuses = []
        }
        let hadPreviousEntitlement = !statuses.isEmpty
        let introEligibility = cachedProducts.values.contains(where: { $0.isEligibleForIntroOffer == true })

        var bestState: PremiumAccessState = .free
        var bestMetadata = PremiumAccessMetadata()
        var bestRank = PremiumAccessTier.free

        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }

            guard SubscriptionCatalog.allProductIDs.contains(transaction.productID) else {
                continue
            }

            guard transaction.revocationDate == nil else {
                continue
            }

            let currentProduct = cachedProducts[transaction.productID]
            let status = await transaction.subscriptionStatus
            let entitlementState = Self.entitlementStatus(
                from: status,
                transaction: transaction
            )
            let tier = Self.accessTier(
                from: transaction,
                status: status
            )
            let subscriptionStatus = Self.subscriptionStatus(
                from: transaction,
                introEligibility: introEligibility,
                hadPreviousEntitlement: hadPreviousEntitlement
            )

            if tier > bestRank {
                bestRank = tier
                bestState = PremiumAccessState(
                    tier: tier,
                    metadata: PremiumAccessMetadata(
                        entitlementStatus: entitlementState,
                        subscriptionExpirationDate: transaction.expirationDate ?? Self.expirationDate(from: status),
                        billingRetryState: Self.billingRetryState(from: status),
                        introductoryOfferEligibility: introEligibility,
                        subscriptionStatus: subscriptionStatus,
                        productInfo: currentProduct?.premiumProductInfo
                    )
                )
                continue
            }

            if tier == bestRank, bestRank != .free {
                bestMetadata = PremiumAccessMetadata(
                    entitlementStatus: entitlementState,
                    subscriptionExpirationDate: transaction.expirationDate ?? Self.expirationDate(from: status),
                    billingRetryState: Self.billingRetryState(from: status),
                    introductoryOfferEligibility: introEligibility,
                    subscriptionStatus: subscriptionStatus,
                    productInfo: currentProduct?.premiumProductInfo
                )
                bestState = PremiumAccessState(tier: tier, metadata: bestMetadata)
            }
        }

        if bestRank == .free {
            return PremiumAccessState(
                tier: .free,
                metadata: PremiumAccessMetadata(
                    entitlementStatus: hadPreviousEntitlement ? .expired : nil,
                    introductoryOfferEligibility: introEligibility,
                    subscriptionStatus: .free(
                        isEligibleForIntroOffer: introEligibility,
                        hadPreviousEntitlement: hadPreviousEntitlement
                    ),
                    productInfo: cachedProducts.values.first?.premiumProductInfo
                )
            )
        }

        return bestState
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        if cachedProducts[productID] == nil {
            _ = try await loadProducts()
        }

        guard let product = try await product(for: productID) else {
            #if DEBUG
            if usesFallbackCatalog, let developmentState = developmentPurchaseState(for: productID) {
                developmentAccessState = developmentState
                return .success
            }
            #endif
            throw SubscriptionManagerError.unknownProduct(productID)
        }

        do {
            switch try await product.purchase() {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    throw SubscriptionManagerError.verificationFailed
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                throw SubscriptionManagerError.purchaseFailed
            }
        } catch {
            #if DEBUG
            if usesFallbackCatalog, let developmentState = developmentPurchaseState(for: productID) {
                developmentAccessState = developmentState
                return .success
            }
            #endif
            throw SubscriptionManagerError.purchaseFailed
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    func observeTransactionUpdates(onUpdate: @escaping @Sendable () async -> Void) -> SubscriptionUpdateObservation {
        updateTask?.cancel()
        updateTask = Task {
            for await verificationResult in StoreKit.Transaction.updates {
                guard !Task.isCancelled else { break }

                guard case .verified(let transaction) = verificationResult else {
                    continue
                }

                guard SubscriptionCatalog.allProductIDs.contains(transaction.productID) else {
                    continue
                }

                await transaction.finish()
                await onUpdate()
            }
        }

        return SubscriptionUpdateObservation { [weak self] in
            self?.updateTask?.cancel()
            self?.updateTask = nil
        }
    }

    private func product(for productID: String) async throws -> Product? {
        let products = try await Product.products(for: [productID])
        return products.first
    }

    private static func mapProduct(_ product: Product) async -> SubscriptionProduct? {
        guard SubscriptionCatalog.allProductIDs.contains(product.id) else {
            return nil
        }

        let subscription = product.subscription
        let subscriptionPeriodDescription = subscription.flatMap { Self.subscriptionPeriodDescription(for: $0) }
        let introductoryOfferDescription = subscription.flatMap { Self.introductoryOfferDescription(for: $0) }
        let subscriptionGroupDisplayName = subscription?.groupDisplayName
        let subscriptionGroupID = subscription?.subscriptionGroupID
        let isEligibleForIntroOffer = await subscription?.isEligibleForIntroOffer
        let storefrontName: String? = nil

        return SubscriptionProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            subscriptionPeriodDescription: subscriptionPeriodDescription,
            introductoryOfferDescription: introductoryOfferDescription,
            subscriptionGroupID: subscriptionGroupID,
            subscriptionGroupDisplayName: subscriptionGroupDisplayName,
            storefrontName: storefrontName,
            isEligibleForIntroOffer: isEligibleForIntroOffer
        )
    }

    private func subscriptionStatuses(for groupID: String?) async throws -> [Product.SubscriptionInfo.Status] {
        guard let groupID else {
            return []
        }

        return try await Product.SubscriptionInfo.status(for: groupID)
    }

    private static func subscriptionStatus(
        from transaction: StoreKit.Transaction,
        introEligibility: Bool,
        hadPreviousEntitlement: Bool
    ) -> PremiumSubscriptionStatus {
        if transaction.offer?.type == .introductory {
            return .activeTrial
        }

        if transaction.revocationDate == nil {
            return .activePaid
        }

        return .free(
            isEligibleForIntroOffer: introEligibility,
            hadPreviousEntitlement: hadPreviousEntitlement
        )
    }

    private static func subscriptionPeriodDescription(for subscription: Product.SubscriptionInfo) -> String? {
        let period = subscription.subscriptionPeriod
        return Self.periodDescription(period)
    }

    private static func introductoryOfferDescription(for subscription: Product.SubscriptionInfo) -> String? {
        guard let offer = subscription.introductoryOffer else {
            return nil
        }

        let periodDescription = Self.periodDescription(offer.period)
        if offer.paymentMode == .freeTrial {
            return periodDescription.map { "Free trial for \($0)" } ?? "Free trial"
        }

        if offer.paymentMode == .payAsYouGo {
            return periodDescription.map { "Intro offer for \($0)" } ?? "Intro offer"
        }

        if offer.paymentMode == .payUpFront {
            return periodDescription.map { "Up-front intro offer for \($0)" } ?? "Up-front intro offer"
        }

        return "Intro offer"
    }

    private static func periodDescription(_ period: Product.SubscriptionPeriod) -> String? {
        let unitName: String
        switch period.unit {
        case .day:
            unitName = period.value == 1 ? "day" : "days"
        case .week:
            unitName = period.value == 1 ? "week" : "weeks"
        case .month:
            unitName = period.value == 1 ? "month" : "months"
        case .year:
            unitName = period.value == 1 ? "year" : "years"
        @unknown default:
            unitName = "period"
        }

        if period.value == 1 {
            return unitName
        }

        return "\(period.value) \(unitName)"
    }

    private static func accessTier(
        from transaction: StoreKit.Transaction,
        status: Product.SubscriptionInfo.Status?
    ) -> PremiumAccessTier {
        if let offer = transaction.offer, offer.type == .introductory {
            return .trial
        }

        if let status {
            if status.state == .subscribed || status.state == .inGracePeriod {
                return .premium
            }

            if status.state == .expired || status.state == .inBillingRetryPeriod || status.state == .revoked {
                return .free
            }
        }

        return .premium
    }

    private static func entitlementStatus(
        from status: Product.SubscriptionInfo.Status?,
        transaction: StoreKit.Transaction
    ) -> PremiumEntitlementStatus? {
        guard let status else {
            return transaction.revocationDate == nil ? .active : .revoked
        }

        if status.state == .subscribed {
            if transaction.offer?.type == .introductory {
                return .trialing
            }
            return .active
        }

        if status.state == .inGracePeriod {
            return .inGracePeriod
        }

        if status.state == .inBillingRetryPeriod {
            return .inBillingRetry
        }

        if status.state == .expired {
            return .expired
        }

        if status.state == .revoked {
            return .revoked
        }

        return .active
    }

    private static func billingRetryState(from status: Product.SubscriptionInfo.Status?) -> PremiumBillingRetryState? {
        guard let status else {
            return nil
        }

        if status.state == .inGracePeriod {
            return .gracePeriod
        }

        if status.state == .inBillingRetryPeriod {
            return .retrying
        }

        if status.state == .subscribed || status.state == .expired || status.state == .revoked {
            return PremiumBillingRetryState.none
        }

        return nil
    }

    #if DEBUG
    private func developmentPurchaseState(for productID: String) -> PremiumAccessState? {
        guard let product = cachedProducts[productID] ?? cachedProducts.values.first else {
            return nil
        }

        let introductoryOfferEligible = product.isEligibleForIntroOffer ?? true
        let subscriptionStatus: PremiumSubscriptionStatus = introductoryOfferEligible ? .activeTrial : .activePaid

        return PremiumAccessState(
            tier: subscriptionStatus.isActiveTrial ? .trial : .premium,
            metadata: PremiumAccessMetadata(
                entitlementStatus: subscriptionStatus.isActiveTrial ? .trialing : .active,
                introductoryOfferEligibility: introductoryOfferEligible,
                subscriptionStatus: subscriptionStatus,
                productInfo: product.premiumProductInfo
            )
        )
    }
    #endif

    private static func expirationDate(from status: Product.SubscriptionInfo.Status?) -> Date? {
        guard let status else {
            return nil
        }

        guard case .verified(let renewalInfo) = status.renewalInfo else {
            return nil
        }

        return renewalInfo.renewalDate ?? renewalInfo.gracePeriodExpirationDate
    }
}
