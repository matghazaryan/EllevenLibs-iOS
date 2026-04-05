import Foundation

public enum EIntelligenceError: LocalizedError {
    case notConfigured
    case noProviderAvailable
    case geminiAPIKeyMissing
    case appleIntelligenceUnavailable
    case generationFailed(String)
    case invalidResponse
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "EIntelligence has not been configured. Call configure() first."
        case .noProviderAvailable:
            return "No LLM provider is available. Enable at least one provider."
        case .geminiAPIKeyMissing:
            return "Gemini API key is required when Gemini is enabled."
        case .appleIntelligenceUnavailable:
            return "Apple Intelligence is not available on this device."
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .invalidResponse:
            return "Received an invalid response from the provider."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
