import Foundation

/// Configuration for EStore. Products are REQUIRED.
///
/// Usage:
///     let config = EStoreConfig(
///         products: [
///             EStoreProductConfig(
///                 id: "com.app.monthly",
///                 type: .subscription,
///                 localizedTitles: ["en": "Monthly Pro", "es": "Pro Mensual"],
///                 localizedDescriptions: ["en": "Full access every month", "es": "Acceso completo cada mes"]
///             ),
///             EStoreProductConfig(
///                 id: "com.app.lifetime",
///                 type: .oneTime,
///                 localizedTitles: ["en": "Lifetime"],
///                 localizedDescriptions: ["en": "Pay once, access forever"]
///             ),
///             EStoreProductConfig(
///                 id: "com.app.coins100",
///                 type: .consumable(amount: 100),
///                 localizedTitles: ["en": "100 Coins"],
///                 localizedDescriptions: ["en": "Buy 100 coins"]
///             )
///         ],
///         theme: EStoreTheme(primaryColor: .blue)
///     )
/// A premium feature displayed in paywalls.
public struct EStoreFeature {
    public let icon: String
    public let title: String
    public let subtitle: String?

    /// - Parameters:
    ///   - icon: SF Symbol name (iOS) or emoji/text (Android)
    ///   - title: Feature title
    ///   - subtitle: Optional description
    public init(icon: String = "checkmark.circle.fill", title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}

public struct EStoreConfig {
    public let products: [EStoreProductConfig]
    public let features: [EStoreFeature]
    public var theme: EStoreTheme

    /// - Parameters:
    ///   - products: Product configurations (REQUIRED, at least one)
    ///   - features: Premium features shown in paywalls (e.g., "Ad Free", "Unlimited Projects")
    ///   - theme: Theme colors for paywalls
    public init(products: [EStoreProductConfig], features: [EStoreFeature] = [], theme: EStoreTheme = .default) {
        precondition(!products.isEmpty, "[EStore] ERROR: You must provide at least one product configuration.")
        self.products = products
        self.features = features
        self.theme = theme
    }

    internal var subscriptionIds: [String] {
        products.filter { if case .subscription = $0.type { return true }; return false }.map(\.id)
    }

    internal var oneTimeIds: [String] {
        products.filter { if case .oneTime = $0.type { return true }; return false }.map(\.id)
    }

    internal var consumableIds: [String] {
        products.filter { if case .consumable = $0.type { return true }; return false }.map(\.id)
    }
}

/// Configuration for a single product.
public struct EStoreProductConfig: Identifiable {
    public let id: String
    public let type: EStoreProductType
    public let localizedTitles: [String: String]
    public let localizedDescriptions: [String: String]
    public let iconName: String?

    public init(
        id: String,
        type: EStoreProductType,
        localizedTitles: [String: String],
        localizedDescriptions: [String: String],
        iconName: String? = nil
    ) {
        precondition(!localizedTitles.isEmpty, "[EStore] ERROR: Product '\(id)' must have at least one localized title.")
        precondition(!localizedDescriptions.isEmpty, "[EStore] ERROR: Product '\(id)' must have at least one localized description.")
        self.id = id
        self.type = type
        self.localizedTitles = localizedTitles
        self.localizedDescriptions = localizedDescriptions
        self.iconName = iconName
    }

    /// Returns the title for the current device locale, falling back to "en", then first available.
    public func title(for locale: String? = nil) -> String {
        let lang = locale ?? String(Locale.current.language.languageCode?.identifier ?? "en")
        return localizedTitles[lang] ?? localizedTitles["en"] ?? localizedTitles.values.first ?? id
    }

    /// Returns the description for the current device locale, falling back to "en", then first available.
    public func description(for locale: String? = nil) -> String {
        let lang = locale ?? String(Locale.current.language.languageCode?.identifier ?? "en")
        return localizedDescriptions[lang] ?? localizedDescriptions["en"] ?? localizedDescriptions.values.first ?? ""
    }
}

/// The type of a store product.
public enum EStoreProductType: Equatable {
    case subscription
    case oneTime
    case consumable(amount: Int)

    public static func == (lhs: EStoreProductType, rhs: EStoreProductType) -> Bool {
        switch (lhs, rhs) {
        case (.subscription, .subscription), (.oneTime, .oneTime): return true
        case (.consumable(let a), .consumable(let b)): return a == b
        default: return false
        }
    }
}
