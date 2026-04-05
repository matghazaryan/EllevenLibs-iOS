import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence provider - uses on-device Foundation Models (iOS 26+)
@MainActor
final class EAppleIntelligenceProvider {

    /// Check if Apple Intelligence is available on this device
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return LanguageModelSession.isAvailable
        }
        #endif
        return false
    }

    /// Generate text using Apple Intelligence
    static func generate(prompt: String) async throws -> EIntelligenceResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard LanguageModelSession.isAvailable else {
                throw EIntelligenceError.appleIntelligenceUnavailable
            }

            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let text = response.content
                .compactMap { $0.value as? String }
                .joined()

            guard !text.isEmpty else {
                throw EIntelligenceError.invalidResponse
            }

            return EIntelligenceResult(
                output: text,
                provider: .appleIntelligence,
                model: "apple-intelligence-on-device"
            )
        }
        #endif
        throw EIntelligenceError.appleIntelligenceUnavailable
    }
}
