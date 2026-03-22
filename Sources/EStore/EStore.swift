import Foundation
import StoreKit

/// Central manager for in-app purchases, subscriptions, and consumables.
///
/// Usage:
///     // Configure (REQUIRED before any other call)
///     await EStore.shared.configure(EStoreConfig(
///         products: [
///             EStoreProductConfig(id: "monthly", type: .subscription,
///                 localizedTitles: ["en": "Monthly"], localizedDescriptions: ["en": "Monthly access"]),
///             EStoreProductConfig(id: "lifetime", type: .oneTime,
///                 localizedTitles: ["en": "Lifetime"], localizedDescriptions: ["en": "Forever"]),
///             EStoreProductConfig(id: "coins100", type: .consumable(amount: 100),
///                 localizedTitles: ["en": "100 Coins"], localizedDescriptions: ["en": "Buy coins"]),
///         ]
///     ))
///
///     // Check premium (subscriptions + oneTime)
///     if EStore.shared.isPremium { ... }
///
///     // Check consumable balance
///     let coins = EStore.shared.consumableBalance(for: "coins100")
///
///     // Show a paywall
///     EPaywall1()
@MainActor
public final class EStore: ObservableObject {
    public static let shared = EStore()

    @Published public private(set) var isPremium: Bool = false
    @Published public private(set) var products: [EStoreProduct] = []
    @Published public private(set) var purchaseInfo: EStorePurchaseInfo?
    @Published public private(set) var allPurchaseInfos: [EStorePurchaseInfo] = []

    public private(set) var config: EStoreConfig?
    public var theme: EStoreTheme { config?.theme ?? .default }

    private var updateListenerTask: Task<Void, Never>?
    private let premiumCacheKey = "EStore_isPremium"
    private let testPurchasesKey = "EStore_testPurchases"
    private var isTestMode = false
    private var testPurchaseInfos: [EStorePurchaseInfo] = []

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: premiumCacheKey)
    }

    /// Configure with product definitions. MUST be called before using EStore.
    public func configure(_ config: EStoreConfig) async {
        self.config = config

        updateListenerTask?.cancel()
        updateListenerTask = Task {
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await handleTransaction(transaction)
                }
            }
        }

        await fetchProducts()
        await refreshPurchaseStatus()
    }

    // MARK: - Purchase

    @discardableResult
    public func purchase(_ productId: String) async throws -> EStorePurchaseResult {
        guard let product = products.first(where: { $0.id == productId }) else {
            throw EStoreError.productNotFound
        }

        // Test mode: simulate purchase
        if isTestMode || product.isTestProduct {
            print("[EStore] [TEST] Simulating purchase: \(productId)")
            if case .consumable(let amount) = product.type {
                EStoreConsumableManager.shared.increment(productId: productId, by: amount)
            } else {
                let info = EStoreTestConfig.createTestPurchaseInfo(product: product)
                testPurchaseInfos.append(info)
                saveTestPurchases()
                updateTestPurchaseState()
            }
            return .success
        }

        guard let storeKitProduct = product.storeKitProduct else {
            throw EStoreError.productNotFound
        }

        let result = try await storeKitProduct.purchase()

        switch result {
        case .success(let verification):
            if let transaction = try? verification.payloadValue {
                await transaction.finish()
                if case .consumable(let amount) = product.type {
                    EStoreConsumableManager.shared.increment(productId: productId, by: amount)
                }
                await refreshPurchaseStatus()
                return .success
            }
            return .failed
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed
        }
    }

    /// Restore previous purchases.
    public func restore() async throws {
        if isTestMode {
            loadTestPurchases()
            return
        }
        try await AppStore.sync()
        await refreshPurchaseStatus()
    }

    /// Clear all test purchases (test mode only).
    public func clearTestPurchases() {
        guard isTestMode else { return }
        print("[EStore] [TEST] Clearing all test purchases")
        testPurchaseInfos.removeAll()
        UserDefaults.standard.removeObject(forKey: testPurchasesKey)
        updateTestPurchaseState()
    }

    // MARK: - Consumables

    /// Get the current balance for a consumable product.
    public func consumableBalance(for productId: String) -> Int {
        EStoreConsumableManager.shared.balance(for: productId)
    }

    /// Deduct from a consumable balance. Returns false if insufficient.
    @discardableResult
    public func deductConsumable(_ productId: String, amount: Int) -> Bool {
        EStoreConsumableManager.shared.deduct(productId: productId, by: amount)
    }

    /// Add to a consumable balance (e.g., from rewarded ad).
    public func addConsumable(_ productId: String, amount: Int) {
        EStoreConsumableManager.shared.increment(productId: productId, by: amount)
    }

    // MARK: - Real-time verification

    /// Force-check premium status against StoreKit. Called automatically but can be triggered manually.
    public func verifyPremiumStatus() async {
        await refreshPurchaseStatus()
    }

    // MARK: - Helpers

    /// Get the product config for a product ID
    public func productConfig(for id: String) -> EStoreProductConfig? {
        config?.products.first(where: { $0.id == id })
    }

    // MARK: - Internal

    private func fetchProducts() async {
        guard let config = config else { return }
        let allIds = Set(config.products.map(\.id))
        guard !allIds.isEmpty else { return }

        print("[EStore] Fetching \(allIds.count) products: \(allIds)")

        do {
            let storeProducts = try await Product.products(for: allIds)
            print("[EStore] StoreKit returned \(storeProducts.count) products")

            if storeProducts.isEmpty && EStoreTestConfig.isDebug {
                // Fallback: parse .storekit config file from bundle
                print("[EStore] DEBUG: StoreKit returned 0 products, falling back to .storekit config file")
                let testProducts = EStoreTestConfig.loadTestProducts(config: config)
                if !testProducts.isEmpty {
                    isTestMode = true
                    products = testProducts
                    loadTestPurchases()
                    print("[EStore] Test mode enabled with \(testProducts.count) products from .storekit file")
                    return
                }
            }

            products = storeProducts.compactMap { product in
                guard let productConfig = config.products.first(where: { $0.id == product.id }) else { return nil }
                return EStoreProduct(from: product, config: productConfig)
            }.sorted { $0.price < $1.price }
            print("[EStore] Loaded \(products.count) products")
        } catch {
            print("[EStore] Failed to fetch products: \(error.localizedDescription)")
            // Fallback on error in debug
            if EStoreTestConfig.isDebug {
                let testProducts = EStoreTestConfig.loadTestProducts(config: config)
                if !testProducts.isEmpty {
                    isTestMode = true
                    products = testProducts
                    loadTestPurchases()
                    print("[EStore] Test mode enabled (fallback) with \(testProducts.count) products")
                }
            }
        }
    }

    private func refreshPurchaseStatus() async {
        guard let config = config else { return }
        var infos: [EStorePurchaseInfo] = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                let productConfig = config.products.first(where: { $0.id == transaction.productID })
                let type = productConfig?.type ?? .oneTime
                infos.append(EStorePurchaseInfo(from: transaction, type: type))
            }
        }

        allPurchaseInfos = infos
        purchaseInfo = infos.first
        // isPremium = any active subscription or oneTime (NOT consumable)
        let newPremium = infos.contains { info in
            if case .consumable = info.type { return false }
            return true
        }
        isPremium = newPremium
        UserDefaults.standard.set(newPremium, forKey: premiumCacheKey)
    }

    private func handleTransaction(_ transaction: Transaction) async {
        await transaction.finish()
        if let config = config,
           let productConfig = config.products.first(where: { $0.id == transaction.productID }),
           case .consumable(let amount) = productConfig.type {
            EStoreConsumableManager.shared.increment(productId: transaction.productID, by: amount)
        }
        await refreshPurchaseStatus()
    }

    // MARK: - Test Purchase Persistence

    private func updateTestPurchaseState() {
        allPurchaseInfos = testPurchaseInfos
        purchaseInfo = testPurchaseInfos.first
        let newPremium = testPurchaseInfos.contains { info in
            if case .consumable = info.type { return false }
            return true
        }
        isPremium = newPremium
        UserDefaults.standard.set(newPremium, forKey: premiumCacheKey)
    }

    private func saveTestPurchases() {
        let data = testPurchaseInfos.map { info -> [String: Any] in
            var dict: [String: Any] = [
                "productId": info.productId,
                "purchaseDate": info.purchaseDate.timeIntervalSince1970,
                "transactionId": info.transactionId,
            ]
            switch info.type {
            case .subscription: dict["type"] = "subscription"
            case .oneTime: dict["type"] = "oneTime"
            case .consumable: dict["type"] = "consumable"
            }
            if let exp = info.expirationDate {
                dict["expirationDate"] = exp.timeIntervalSince1970
            }
            return dict
        }
        UserDefaults.standard.set(data, forKey: testPurchasesKey)
    }

    private func loadTestPurchases() {
        testPurchaseInfos.removeAll()
        guard let data = UserDefaults.standard.array(forKey: testPurchasesKey) as? [[String: Any]] else {
            updateTestPurchaseState()
            return
        }
        for dict in data {
            guard let productId = dict["productId"] as? String,
                  let purchaseTime = dict["purchaseDate"] as? TimeInterval,
                  let transactionId = dict["transactionId"] as? UInt64,
                  let typeStr = dict["type"] as? String else { continue }

            let type: EStoreProductType = switch typeStr {
            case "subscription": .subscription
            case "consumable": .consumable(amount: 0)
            default: .oneTime
            }
            let expiration = (dict["expirationDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }

            testPurchaseInfos.append(EStorePurchaseInfo(
                productId: productId,
                type: type,
                purchaseDate: Date(timeIntervalSince1970: purchaseTime),
                expirationDate: expiration,
                transactionId: transactionId
            ))
        }
        updateTestPurchaseState()
    }
}

public enum EStorePurchaseResult {
    case success, cancelled, pending, failed
}

public enum EStoreError: LocalizedError {
    case productNotFound
    case notConfigured
    case noProductsConfigured
    case insufficientBalance

    public var errorDescription: String? {
        switch self {
        case .productNotFound: return "Product not found."
        case .notConfigured: return "EStore not configured. Call configure() first."
        case .noProductsConfigured: return "No products configured."
        case .insufficientBalance: return "Insufficient consumable balance."
        }
    }
}
