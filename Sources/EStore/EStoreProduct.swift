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
    public let currencyCode: String?
    public let subscriptionPeriod: String?
    /// Trial period (e.g., "2 weeks", "3 days", "1 month"). Nil if no trial.
    public let trialPeriod: String?
    /// Number of trial days. 0 if no trial.
    public let trialDays: Int

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
        self.currencyCode = product.priceFormatStyle.currencyCode
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

        // Extract trial/introductory offer
        if let intro = product.subscription?.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let period = intro.period
            switch period.unit {
            case .day:
                self.trialPeriod = period.value == 1 ? "1 day" : "\(period.value) days"
                self.trialDays = period.value
            case .week:
                self.trialPeriod = period.value == 1 ? "1 week" : "\(period.value) weeks"
                self.trialDays = period.value * 7
            case .month:
                self.trialPeriod = period.value == 1 ? "1 month" : "\(period.value) months"
                self.trialDays = period.value * 30
            case .year:
                self.trialPeriod = period.value == 1 ? "1 year" : "\(period.value) years"
                self.trialDays = period.value * 365
            @unknown default:
                self.trialPeriod = nil
                self.trialDays = 0
            }
        } else {
            self.trialPeriod = nil
            self.trialDays = 0
        }
    }

    /// Creates a test product for debug/simulator use.
    init(testConfig config: EStoreProductConfig, displayPrice: String, price: Decimal, subscriptionPeriod: String?, trialPeriod: String? = nil, trialDays: Int = 0) {
        self.id = config.id
        self.type = config.type
        self.displayName = config.title()
        self.localizedTitle = config.title()
        self.localizedDescription = config.description()
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = "USD"
        self.storeKitProduct = nil
        self.config = config
        self.isTestProduct = true
        self.subscriptionPeriod = subscriptionPeriod
        self.trialPeriod = trialPeriod
        self.trialDays = trialDays
    }
}
