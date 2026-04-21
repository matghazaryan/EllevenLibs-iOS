import Foundation

public enum ESupabaseAnalyticsError: LocalizedError {
    case notConfigured
    case network(String?)
    case server(Int, String?)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ESupabaseAnalytics not configured. Call configure() first."
        case .network(let message):
            return "Network error: \(message ?? "unknown")."
        case .server(let code, let body):
            return "Server error (\(code)): \(body ?? "no body")."
        }
    }
}
