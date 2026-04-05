import Foundation

/// Result of an EIntelligence generation request
public struct EIntelligenceResult {
    /// The generated text output
    public let output: String

    /// Which provider was used to generate the output
    public let provider: EIntelligenceConfig.Provider

    /// The model that was used
    public let model: String
}
