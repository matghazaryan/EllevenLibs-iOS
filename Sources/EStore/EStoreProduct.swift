import Foundation
import StoreKit

/// How an introductory offer charges the subscriber.
public enum EStoreIntroPaymentMode: String, Sendable {
    /// User gets the intro period free (e.g. "7 days free, then $9.99/month").
    case freeTrial
    /// User pays one discounted lump sum for the entire intro period, then
    /// auto-renews at the standard price (e.g. "$39.99 for year 1, then $59.99/year").
    case payUpFront
    /// User pays a reduced per-period price for N billing cycles, then
    /// switches to the standard price (e.g. "$4.99/mo for 3 months, then $9.99/mo").
    case payAsYouGo
}

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

    // MARK: - Introductory offer (any payment mode)

    /// True iff this product currently has an active introductory offer.
    /// Note that StoreKit only returns the offer when the **user is eligible**
    /// (never previously subscribed in this group), so this field already
    /// encodes eligibility for the calling user.
    public let hasIntroductoryOffer: Bool
    /// Localized string of the intro price, e.g. "$39.99" or "$0.00" for free.
    /// Nil if no intro offer.
    public let introductoryDisplayPrice: String?
    /// Raw intro price for math (e.g. 39.99). Nil if no intro offer.
    public let introductoryPrice: Decimal?
    /// Whether the intro offer is free, pay up front, or pay as you go.
    /// Nil if no intro offer.
    public let introductoryPaymentMode: EStoreIntroPaymentMode?
    /// Human-readable intro period (e.g. "1 year", "3 days", "3 months").
    /// Nil if no intro offer.
    public let introductoryPeriod: String?
    /// Approximate intro period in days, for math/sorting. 0 if no intro offer.
    public let introductoryPeriodDays: Int

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

        // Extract introductory offer regardless of payment mode. StoreKit
        // returns the offer struct only when the user is eligible, so this
        // already encodes "is the user eligible for the current campaign".
        if let intro = product.subscription?.introductoryOffer {
            let (periodLabel, periodDays) = Self.formatPeriod(intro.period)
            let mode: EStoreIntroPaymentMode
            switch intro.paymentMode {
            case .freeTrial:  mode = .freeTrial
            case .payUpFront: mode = .payUpFront
            case .payAsYouGo: mode = .payAsYouGo
            default:          mode = .freeTrial
            }

            self.hasIntroductoryOffer = true
            self.introductoryDisplayPrice = intro.displayPrice
            self.introductoryPrice = intro.price
            self.introductoryPaymentMode = mode
            self.introductoryPeriod = periodLabel
            self.introductoryPeriodDays = periodDays

            // Legacy trial-only fields stay populated for the .freeTrial case
            // so existing callers (paywall trial-days badge) keep working.
            if mode == .freeTrial {
                self.trialPeriod = periodLabel
                self.trialDays = periodDays
            } else {
                self.trialPeriod = nil
                self.trialDays = 0
            }
        } else {
            self.hasIntroductoryOffer = false
            self.introductoryDisplayPrice = nil
            self.introductoryPrice = nil
            self.introductoryPaymentMode = nil
            self.introductoryPeriod = nil
            self.introductoryPeriodDays = 0
            self.trialPeriod = nil
            self.trialDays = 0
        }
    }

    /// Turns StoreKit's `Product.SubscriptionPeriod` into a human-readable
    /// label ("1 year", "3 days") and an approximate day count.
    private static func formatPeriod(_ period: Product.SubscriptionPeriod) -> (label: String, days: Int) {
        switch period.unit {
        case .day:   return (period.value == 1 ? "1 day"   : "\(period.value) days",   period.value)
        case .week:  return (period.value == 1 ? "1 week"  : "\(period.value) weeks",  period.value * 7)
        case .month: return (period.value == 1 ? "1 month" : "\(period.value) months", period.value * 30)
        case .year:  return (period.value == 1 ? "1 year"  : "\(period.value) years",  period.value * 365)
        @unknown default: return ("", 0)
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
        // Test products don't carry intro offer details for now. Callers that
        // need to simulate intros can extend this initializer later.
        self.hasIntroductoryOffer = trialDays > 0
        self.introductoryDisplayPrice = trialDays > 0 ? "$0.00" : nil
        self.introductoryPrice = trialDays > 0 ? 0 : nil
        self.introductoryPaymentMode = trialDays > 0 ? .freeTrial : nil
        self.introductoryPeriod = trialPeriod
        self.introductoryPeriodDays = trialDays
    }
}
