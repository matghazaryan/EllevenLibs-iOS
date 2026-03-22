import Foundation

/// Parses .storekit configuration files and creates test products in debug builds.
/// This is the iOS equivalent of Android's estore_test_products.json fallback.
internal struct EStoreTestConfig {

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Attempts to find and parse a .storekit file from the app bundle.
    static func loadTestProducts(config: EStoreConfig) -> [EStoreProduct] {
        guard let url = findStoreKitConfigFile() else {
            print("[EStore] No .storekit config file found in bundle")
            return []
        }

        print("[EStore] Found StoreKit config: \(url.lastPathComponent)")

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[EStore] Failed to parse StoreKit config file")
            return []
        }

        var products: [EStoreProduct] = []

        // Parse subscriptions
        if let groups = json["subscriptionGroups"] as? [[String: Any]] {
            for group in groups {
                if let subs = group["subscriptions"] as? [[String: Any]] {
                    for sub in subs {
                        guard let productId = sub["productID"] as? String else { continue }
                        guard let productConfig = config.products.first(where: { $0.id == productId }) else { continue }

                        let priceStr = sub["displayPrice"] as? String ?? "0.00"
                        let price = Decimal(string: priceStr) ?? 0
                        let period = sub["recurringSubscriptionPeriod"] as? String

                        let periodDisplay: String? = {
                            switch period {
                            case "P1W": return "Weekly"
                            case "P1M": return "Monthly"
                            case "P3M": return "3 months"
                            case "P6M": return "6 months"
                            case "P1Y": return "Yearly"
                            default: return period
                            }
                        }()

                        products.append(EStoreProduct(
                            testConfig: productConfig,
                            displayPrice: "$\(priceStr)",
                            price: price,
                            subscriptionPeriod: periodDisplay
                        ))
                    }
                }
            }
        }

        // Parse non-subscription products (NonConsumable, Consumable)
        if let items = json["products"] as? [[String: Any]] {
            for item in items {
                guard let productId = item["productID"] as? String else { continue }
                guard let productConfig = config.products.first(where: { $0.id == productId }) else { continue }

                let priceStr = item["displayPrice"] as? String ?? "0.00"
                let price = Decimal(string: priceStr) ?? 0

                products.append(EStoreProduct(
                    testConfig: productConfig,
                    displayPrice: "$\(priceStr)",
                    price: price,
                    subscriptionPeriod: nil
                ))
            }
        }

        return products.sorted { $0.price < $1.price }
    }

    /// Creates a simulated purchase info for a test product.
    static func createTestPurchaseInfo(product: EStoreProduct) -> EStorePurchaseInfo {
        let now = Date()
        let expiration: Date? = {
            if case .subscription = product.type {
                // Default to 1 month for test
                return Calendar.current.date(byAdding: .month, value: 1, to: now)
            }
            return nil
        }()

        return EStorePurchaseInfo(
            productId: product.id,
            type: product.type,
            purchaseDate: now,
            expirationDate: expiration,
            transactionId: UInt64(Date().timeIntervalSince1970 * 1000)
        )
    }

    /// Find the first .storekit file in the app bundle.
    private static func findStoreKitConfigFile() -> URL? {
        if let url = Bundle.main.url(forResource: "EStore", withExtension: "storekit") {
            return url
        }
        // Search for any .storekit file
        if let urls = Bundle.main.urls(forResourcesWithExtension: "storekit", subdirectory: nil),
           let first = urls.first {
            return first
        }
        return nil
    }
}
