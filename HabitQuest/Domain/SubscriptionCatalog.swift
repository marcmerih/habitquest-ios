import Foundation

enum SubscriptionCatalog {
    static let monthlyProductID = "com.habitquest.premium.monthly"
    static let annualProductID = "com.habitquest.premium.annual"

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
}
