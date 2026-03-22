import SwiftUI

/// Internal data object that paywalls use to access store state.
@MainActor
internal class EPaywallData: ObservableObject {
    @Published var products: [EStoreProduct] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false

    let theme: EStoreTheme
    let onDismiss: (() -> Void)?

    init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        self.theme = theme ?? EStore.shared.theme
        self.onDismiss = onDismiss
        self.products = EStore.shared.products
        self.isPremium = EStore.shared.isPremium
    }

    func purchase(_ productId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await EStore.shared.purchase(productId)
            if result.status == .success {
                isPremium = EStore.shared.isPremium
                onDismiss?()
            }
        } catch {
            print("[EStore] Purchase error: \(error.localizedDescription)")
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await EStore.shared.restore()
            isPremium = EStore.shared.isPremium
            if isPremium { onDismiss?() }
        } catch {
            print("[EStore] Restore error: \(error.localizedDescription)")
        }
    }

    var subscriptions: [EStoreProduct] {
        products.filter { if case .subscription = $0.type { return true }; return false }
    }

    var oneTimeProducts: [EStoreProduct] {
        products.filter { if case .oneTime = $0.type { return true }; return false }
    }

    var consumables: [EStoreProduct] {
        products.filter { if case .consumable = $0.type { return true }; return false }
    }

    var premiumProducts: [EStoreProduct] {
        subscriptions + oneTimeProducts
    }

    var features: [EStoreFeature] {
        let configured = EStore.shared.config?.features ?? []
        if configured.isEmpty {
            // Default features if none provided
            return [
                EStoreFeature(icon: "checkmark.circle.fill", title: "Unlimited Access"),
                EStoreFeature(icon: "nosign", title: "No Ads"),
                EStoreFeature(icon: "bolt.fill", title: "Premium Features"),
            ]
        }
        return configured
    }
}
