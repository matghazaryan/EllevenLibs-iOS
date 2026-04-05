import Foundation

/// Gemini provider - uses Google's Generative AI REST API
final class EGeminiProvider {

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(prompt: String) async throws -> EIntelligenceResult {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw EIntelligenceError.generationFailed("Invalid URL for model: \(model)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EIntelligenceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EIntelligenceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EIntelligenceError.generationFailed("Gemini API error (\(httpResponse.statusCode)): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw EIntelligenceError.invalidResponse
        }

        return EIntelligenceResult(
            output: text,
            provider: .gemini,
            model: model
        )
    }
}
