import Foundation
import StoreKit

/// Information about an active purchase.
public struct EStorePurchaseInfo: Identifiable {
    public var id: String { productId }
    public let productId: String
    public let type: EStoreProductType
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let transactionId: UInt64

    init(from transaction: Transaction, type: EStoreProductType) {
        self.productId = transaction.productID
        self.type = type
        self.purchaseDate = transaction.purchaseDate
        self.expirationDate = transaction.expirationDate
        self.transactionId = transaction.id
    }

    /// Creates a test purchase info (for debug/simulator).
    init(productId: String, type: EStoreProductType, purchaseDate: Date, expirationDate: Date?, transactionId: UInt64) {
        self.productId = productId
        self.type = type
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.transactionId = transactionId
    }
}
