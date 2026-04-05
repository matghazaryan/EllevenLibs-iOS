import Foundation

/// EIntelligence - Smart AI text generation library
///
/// Automatically routes requests to the best available provider:
/// 1. Apple Intelligence (free, on-device) if available and enabled
/// 2. Gemini (cloud) as fallback
///
/// Usage:
/// ```swift
/// // Configure with Gemini API key
/// EIntelligence.shared.configure(
///     EIntelligenceConfig(geminiAPIKey: "your-api-key")
/// )
///
/// // Generate text
/// let result = try await EIntelligence.shared.generate(prompt: "Hello, world!")
/// print(result.output)
/// print(result.provider) // Shows which provider was used
/// ```
@MainActor
public final class EIntelligence {

    public static let shared = EIntelligence()

    private var config: EIntelligenceConfig?
    private var geminiProvider: EGeminiProvider?

    private init() {}

    // MARK: - Configuration

    /// Configure EIntelligence with the given config
    public func configure(_ config: EIntelligenceConfig) {
        self.config = config

        if config.geminiEnabled, let apiKey = config.geminiAPIKey {
            self.geminiProvider = EGeminiProvider(apiKey: apiKey, model: config.geminiModel)
        } else {
            self.geminiProvider = nil
        }
    }

    // MARK: - Generation

    /// Generate text from a prompt using the best available provider
    ///
    /// Smart routing order (when `preferFreeProvider` is true):
    /// 1. Apple Intelligence (if enabled and available on device)
    /// 2. Gemini (if enabled and API key provided)
    ///
    /// - Parameter prompt: The input text prompt
    /// - Parameter provider: Force a specific provider (optional, overrides smart routing)
    /// - Returns: `EIntelligenceResult` with the generated text and provider info
    public func generate(
        prompt: String,
        provider: EIntelligenceConfig.Provider? = nil
    ) async throws -> EIntelligenceResult {
        guard let config else {
            throw EIntelligenceError.notConfigured
        }

        // If a specific provider is requested, use it directly
        if let provider {
            return try await generateWith(provider: provider, prompt: prompt, config: config)
        }

        // Smart routing: try providers in order of preference
        if config.preferFreeProvider {
            // Try Apple Intelligence first (free, on-device)
            if config.appleIntelligenceEnabled && EAppleIntelligenceProvider.isAvailable {
                do {
                    return try await EAppleIntelligenceProvider.generate(prompt: prompt)
                } catch {
                    // Fall through to next provider
                }
            }

            // Fall back to Gemini
            if config.geminiEnabled, let gemini = geminiProvider {
                return try await gemini.generate(prompt: prompt)
            }
        } else {
            // Gemini first, Apple Intelligence as fallback
            if config.geminiEnabled, let gemini = geminiProvider {
                return try await gemini.generate(prompt: prompt)
            }

            if config.appleIntelligenceEnabled && EAppleIntelligenceProvider.isAvailable {
                return try await EAppleIntelligenceProvider.generate(prompt: prompt)
            }
        }

        throw EIntelligenceError.noProviderAvailable
    }

    // MARK: - Provider Status

    /// Check if Apple Intelligence is available on this device
    public var isAppleIntelligenceAvailable: Bool {
        EAppleIntelligenceProvider.isAvailable
    }

    /// Check if any provider is configured and available
    public var isConfigured: Bool {
        config != nil
    }

    /// Returns the list of currently available providers based on config and device
    public var availableProviders: [EIntelligenceConfig.Provider] {
        guard let config else { return [] }
        var providers: [EIntelligenceConfig.Provider] = []

        if config.appleIntelligenceEnabled && EAppleIntelligenceProvider.isAvailable {
            providers.append(.appleIntelligence)
        }
        if config.geminiEnabled && geminiProvider != nil {
            providers.append(.gemini)
        }

        return providers
    }

    // MARK: - Private

    private func generateWith(
        provider: EIntelligenceConfig.Provider,
        prompt: String,
        config: EIntelligenceConfig
    ) async throws -> EIntelligenceResult {
        switch provider {
        case .appleIntelligence:
            guard config.appleIntelligenceEnabled else {
                throw EIntelligenceError.appleIntelligenceUnavailable
            }
            return try await EAppleIntelligenceProvider.generate(prompt: prompt)

        case .gemini:
            guard config.geminiEnabled, let gemini = geminiProvider else {
                throw EIntelligenceError.geminiAPIKeyMissing
            }
            return try await gemini.generate(prompt: prompt)
        }
    }
}
