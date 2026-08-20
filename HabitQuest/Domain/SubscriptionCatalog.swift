import Foundation

enum SubscriptionCatalog {
    static let monthlyProductID = "com.habitquest.premium.monthly"
    static let annualProductID = "com.habitquest.premium.annual"
    static let premiumSubscriptionGroupID = "HQPREMIUM-GROUP-01"

    static let allProductIDs: [String] = [
        monthlyProductID,
        annualProductID
    ]

    static func sortOrder(for productID: String) -> Int {
        switch productID {
        case monthlyProductID:
            return 0
        case annualProductID:
            return 1
        default:
            return 99
        }
    }

    static func fallbackProducts(isEligibleForIntroOffer: Bool? = true) -> [SubscriptionProduct] {
        [
            SubscriptionProduct(
                id: monthlyProductID,
                displayName: "HabitQuest Premium Monthly",
                displayPrice: "$6.99",
                subscriptionPeriodDescription: "1 month",
                introductoryOfferDescription: "7-day free trial",
                subscriptionGroupID: premiumSubscriptionGroupID,
                subscriptionGroupDisplayName: "HabitQuest Premium",
                isEligibleForIntroOffer: isEligibleForIntroOffer
            ),
            SubscriptionProduct(
                id: annualProductID,
                displayName: "HabitQuest Premium Annual",
                displayPrice: "$59.99",
                subscriptionPeriodDescription: "1 year",
                introductoryOfferDescription: "7-day free trial",
                subscriptionGroupID: premiumSubscriptionGroupID,
                subscriptionGroupDisplayName: "HabitQuest Premium",
                isEligibleForIntroOffer: isEligibleForIntroOffer
            )
        ]
    }
}
