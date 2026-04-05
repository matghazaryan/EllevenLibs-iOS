import Foundation

/// Configuration for EIntelligence
public struct EIntelligenceConfig {

    /// Available LLM providers
    public enum Provider: String, CaseIterable {
        case appleIntelligence
        case gemini
    }

    /// Whether Apple Intelligence is enabled (iOS only, ignored on other platforms)
    public let appleIntelligenceEnabled: Bool

    /// Whether Gemini is enabled
    public let geminiEnabled: Bool

    /// Gemini API key (required if Gemini is enabled)
    public let geminiAPIKey: String?

    /// Gemini model identifier (default: "gemini-2.5-flash")
    public let geminiModel: String

    /// Whether to prefer Apple Intelligence over paid services when available
    /// When true, Apple Intelligence is tried first before falling back to Gemini
    public let preferFreeProvider: Bool

    public init(
        appleIntelligenceEnabled: Bool = true,
        geminiEnabled: Bool = true,
        geminiAPIKey: String? = nil,
        geminiModel: String = "gemini-2.5-flash",
        preferFreeProvider: Bool = true
    ) {
        self.appleIntelligenceEnabled = appleIntelligenceEnabled
        self.geminiEnabled = geminiEnabled
        self.geminiAPIKey = geminiAPIKey
        self.geminiModel = geminiModel
        self.preferFreeProvider = preferFreeProvider
    }
}
