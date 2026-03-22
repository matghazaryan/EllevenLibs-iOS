import Foundation

/// Manages local consumable balances (coins, credits, etc.).
/// Balances are persisted in UserDefaults.
internal final class EStoreConsumableManager {
    static let shared = EStoreConsumableManager()

    private let prefix = "EStore_consumable_"
    private let defaults = UserDefaults.standard

    private init() {}

    func balance(for productId: String) -> Int {
        defaults.integer(forKey: prefix + productId)
    }

    func increment(productId: String, by amount: Int) {
        let current = balance(for: productId)
        defaults.set(current + amount, forKey: prefix + productId)
    }

    func deduct(productId: String, by amount: Int) -> Bool {
        let current = balance(for: productId)
        guard current >= amount else { return false }
        defaults.set(current - amount, forKey: prefix + productId)
        return true
    }

    func reset(productId: String) {
        defaults.set(0, forKey: prefix + productId)
    }
}
