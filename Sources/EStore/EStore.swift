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
    @Published public private(set) var loadingState: EStoreLoadingState = .idle

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
    /// Whether the App Store applied a free-trial offer to this specific
    /// transaction.
    ///
    /// `Transaction.offer` carries the payment mode directly but is only
    /// available from iOS 17.2. On earlier systems the transaction reports the
    /// offer *type* only, so an introductory offer is cross-referenced against
    /// the product's introductory offer to recover its payment mode.
    private static func isFreeTrial(
        transaction: Transaction,
        storeKitProduct: Product
    ) -> Bool {
        if #available(iOS 17.2, macOS 14.2, *) {
            guard let offer = transaction.offer else { return false }
            return offer.paymentMode == .freeTrial
        }
        guard transaction.offerType == .introductory else { return false }
        return storeKitProduct.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// - Parameter appAccountToken: Your own account identifier for the buyer.
    ///   Apple echoes it back in App Store Server Notifications, and it is the
    ///   *only* way a server-side renewal or refund can be attributed to a
    ///   user — without it the webhook receives a transaction it cannot map to
    ///   an account. Must be a UUID; pass the Supabase user id.
    public func purchase(
        _ productId: String,
        appAccountToken: UUID? = nil
    ) async throws -> EStorePurchaseResult {
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
            return EStorePurchaseResult(
                status: .success,
                productId: productId,
                displayPrice: product.displayPrice,
                price: product.price,
                currencyCode: product.currencyCode,
                type: product.type,
                subscriptionPeriod: product.subscriptionPeriod,
                trialPeriod: product.trialPeriod,
                // No real transaction exists in test mode, so simulate the
                // first-purchase path: a trial-bearing product starts its trial.
                isFreeTrial: product.trialPeriod != nil,
                paidPrice: product.trialPeriod != nil ? 0 : product.price,
                purchaseDate: Date(),
                expirationDate: EStoreTestConfig.createTestPurchaseInfo(product: product).expirationDate,
                transactionId: "\(UInt64(Date().timeIntervalSince1970 * 1000))",
                environment: "Test"
            )
        }

        guard let storeKitProduct = product.storeKitProduct else {
            throw EStoreError.productNotFound
        }

        var purchaseOptions: Set<Product.PurchaseOption> = []
        if let appAccountToken {
            purchaseOptions.insert(.appAccountToken(appAccountToken))
        }
        let skResult = try await storeKitProduct.purchase(options: purchaseOptions)

        switch skResult {
        case .success(let verification):
            if let transaction = try? verification.payloadValue {
                await transaction.finish()
                if case .consumable(let amount) = product.type {
                    EStoreConsumableManager.shared.increment(productId: productId, by: amount)
                }
                await refreshPurchaseStatus()
                // A verified successful purchase is proof of entitlement. Apple's
                // `Transaction.currentEntitlements` can come back empty in the
                // moment right after a purchase, which would leave `isPremium`
                // false even though the user just paid. For non-consumables,
                // seed the just-purchased transaction into our state directly so
                // the UI updates immediately; the updates listener and later
                // refreshes reconcile it.
                if case .consumable = product.type {} else {
                    let info = EStorePurchaseInfo(from: transaction, type: product.type)
                    if !allPurchaseInfos.contains(where: { $0.transactionId == info.transactionId }) {
                        allPurchaseInfos.append(info)
                    }
                    if purchaseInfo == nil { purchaseInfo = info }
                    if !isPremium {
                        isPremium = true
                        UserDefaults.standard.set(true, forKey: premiumCacheKey)
                    }
                }
                return EStorePurchaseResult(
                    status: .success,
                    productId: productId,
                    displayPrice: product.displayPrice,
                    price: product.price,
                    currencyCode: product.currencyCode,
                    type: product.type,
                    subscriptionPeriod: product.subscriptionPeriod,
                    trialPeriod: product.trialPeriod,
                    isFreeTrial: Self.isFreeTrial(
                        transaction: transaction,
                        storeKitProduct: storeKitProduct
                    ),
                    paidPrice: transaction.price,
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate,
                    transactionId: "\(transaction.id)",
                    environment: transaction.environment.rawValue
                )
            }
            return EStorePurchaseResult(status: .failed, productId: productId)
        case .userCancelled:
            return EStorePurchaseResult(status: .cancelled, productId: productId)
        case .pending:
            return EStorePurchaseResult(status: .pending, productId: productId)
        @unknown default:
            return EStorePurchaseResult(status: .failed, productId: productId)
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
        guard let config = config else {
            loadingState = .failed(EStoreError.notConfigured)
            return
        }
        let allIds = Set(config.products.map(\.id))
        guard !allIds.isEmpty else {
            loadingState = .failed(EStoreError.noProductsConfigured)
            return
        }

        loadingState = .loading
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
                    loadingState = .loaded
                    print("[EStore] Test mode enabled with \(testProducts.count) products from .storekit file")
                    return
                }
            }

            products = storeProducts.compactMap { product in
                guard let productConfig = config.products.first(where: { $0.id == product.id }) else { return nil }
                return EStoreProduct(from: product, config: productConfig)
            }.sorted { $0.price < $1.price }

            if products.isEmpty {
                loadingState = .failed(EStoreError.productsLoadEmpty)
                print("[EStore] WARNING: StoreKit returned products but none matched configured IDs")
            } else {
                loadingState = .loaded
                print("[EStore] Loaded \(products.count) products")
            }
        } catch {
            print("[EStore] Failed to fetch products: \(error.localizedDescription)")
            loadingState = .failed(error)
            // Fallback on error in debug
            if EStoreTestConfig.isDebug {
                let testProducts = EStoreTestConfig.loadTestProducts(config: config)
                if !testProducts.isEmpty {
                    isTestMode = true
                    products = testProducts
                    loadTestPurchases()
                    loadingState = .loaded
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

/// Rich result returned after a purchase attempt. Contains all transaction data.
public struct EStorePurchaseResult {
    /// The outcome of the purchase.
    public let status: EStorePurchaseStatus
    /// The product ID that was purchased.
    public let productId: String
    /// Formatted price string (e.g., "$4.99").
    public let displayPrice: String?
    /// Raw price as Decimal.
    public let price: Decimal?
    /// Currency code (e.g., "USD").
    public let currencyCode: String?
    /// Product type (subscription, oneTime, consumable).
    public let type: EStoreProductType?
    /// Subscription period (e.g., "Monthly", "Yearly"). Nil for non-subscriptions.
    public let subscriptionPeriod: String?
    /// Trial period the *product* advertises (e.g., "2 weeks"). Nil if the
    /// product has no introductory offer.
    ///
    /// - Important: This describes the product, **not** this transaction. A
    ///   product that advertises a trial can still be bought at full price
    ///   (the user was already past their trial, or ineligible). Use
    ///   ``isFreeTrial`` to decide whether money actually changed hands.
    public let trialPeriod: String?
    /// True only when the App Store applied a **free-trial** offer to *this*
    /// transaction — i.e. the user was charged nothing right now.
    ///
    /// Derived from the transaction's applied offer, not from the product.
    /// A paid introductory offer ("30% off the first year") is a real
    /// purchase and reports `false` here.
    public let isFreeTrial: Bool
    /// What the store actually charged for this transaction, which differs
    /// from ``price`` whenever an introductory or promotional offer applied.
    /// Nil when the store did not report a price.
    public let paidPrice: Decimal?
    /// When the purchase was made.
    public let purchaseDate: Date?
    /// When the subscription expires. Nil for lifetime/consumable.
    public let expirationDate: Date?
    /// Transaction ID from the store.
    ///
    /// - Important: Only unique within ``environment``. Xcode's local StoreKit
    ///   store numbers transactions from 1 and restarts the counter whenever
    ///   the test store is reset, so a debug transaction id will collide with
    ///   both other debug ids and low-numbered ids from other environments.
    ///   Namespace by ``environment`` before using this as a durable key.
    public let transactionId: String?
    /// Which App Store issued the transaction — `"Production"`, `"Sandbox"`,
    /// or `"Xcode"`. `"Test"` for simulated purchases in test mode. Nil when
    /// the store did not report one.
    public let environment: String?

    init(
        status: EStorePurchaseStatus,
        productId: String,
        displayPrice: String? = nil,
        price: Decimal? = nil,
        currencyCode: String? = nil,
        type: EStoreProductType? = nil,
        subscriptionPeriod: String? = nil,
        trialPeriod: String? = nil,
        isFreeTrial: Bool = false,
        paidPrice: Decimal? = nil,
        purchaseDate: Date? = nil,
        expirationDate: Date? = nil,
        transactionId: String? = nil,
        environment: String? = nil
    ) {
        self.status = status
        self.productId = productId
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.type = type
        self.subscriptionPeriod = subscriptionPeriod
        self.trialPeriod = trialPeriod
        self.isFreeTrial = isFreeTrial
        self.paidPrice = paidPrice
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.transactionId = transactionId
        self.environment = environment
    }
}

public enum EStorePurchaseStatus {
    case success, cancelled, pending, failed
}

public enum EStoreLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(Error)

    public static func == (lhs: EStoreLoadingState, rhs: EStoreLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
        case (.failed(let a), .failed(let b)): return a.localizedDescription == b.localizedDescription
        default: return false
        }
    }

    public var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

public enum EStoreError: LocalizedError {
    case productNotFound
    case notConfigured
    case noProductsConfigured
    case insufficientBalance
    case productsLoadEmpty

    public var errorDescription: String? {
        switch self {
        case .productNotFound: return "Product not found."
        case .notConfigured: return "EStore not configured. Call configure() first."
        case .noProductsConfigured: return "No products configured."
        case .insufficientBalance: return "Insufficient consumable balance."
        case .productsLoadEmpty: return "Products loaded but none matched configured IDs. Check your product IDs in App Store Connect."
        }
    }
}
