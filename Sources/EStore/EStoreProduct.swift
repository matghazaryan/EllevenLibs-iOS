import Foundation
import StoreKit

/// A product available for purchase, enriched with store data and config.
public struct EStoreProduct: Identifiable {
    public let id: String
    public let type: EStoreProductType
    public let displayName: String
    public let localizedTitle: String
    public let localizedDescription: String
    public let displayPrice: String
    public let price: Decimal
    public let subscriptionPeriod: String?

    internal let storeKitProduct: Product?
    internal let config: EStoreProductConfig
    internal let isTestProduct: Bool

    init(from product: Product, config: EStoreProductConfig) {
        self.id = product.id
        self.type = config.type
        self.displayName = product.displayName
        self.localizedTitle = config.title()
        self.localizedDescription = config.description()
        self.displayPrice = product.displayPrice
        self.price = product.price
        self.storeKitProduct = product
        self.config = config
        self.isTestProduct = false

        if product.type == .autoRenewable, let period = product.subscription?.subscriptionPeriod {
            switch period.unit {
            case .day: self.subscriptionPeriod = period.value == 7 ? "Weekly" : "\(period.value) day(s)"
            case .week: self.subscriptionPeriod = "\(period.value) week(s)"
            case .month: self.subscriptionPeriod = period.value == 1 ? "Monthly" : "\(period.value) months"
            case .year: self.subscriptionPeriod = period.value == 1 ? "Yearly" : "\(period.value) years"
            @unknown default: self.subscriptionPeriod = nil
            }
        } else {
            self.subscriptionPeriod = nil
        }
    }

    /// Creates a test product for debug/simulator use.
    init(testConfig config: EStoreProductConfig, displayPrice: String, price: Decimal, subscriptionPeriod: String?) {
        self.id = config.id
        self.type = config.type
        self.displayName = config.title()
        self.localizedTitle = config.title()
        self.localizedDescription = config.description()
        self.displayPrice = displayPrice
        self.price = price
        self.storeKitProduct = nil
        self.config = config
        self.isTestProduct = true
        self.subscriptionPeriod = subscriptionPeriod
    }
}
