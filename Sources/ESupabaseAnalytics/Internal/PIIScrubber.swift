import Foundation

/// Scrubs PII / secrets from request and response bodies before they're
/// uploaded to the observability tables.
///
/// Conservative deny list: any key whose lowercase contains one of the deny
/// substrings is replaced with the literal string `"<redacted>"`. Recurses
/// through nested dictionaries and arrays. Non-dictionary input is returned
/// unchanged (so a leaf string body — e.g. a JWT in a 401 response — should
/// be wrapped in `{ "raw": ... }` by the caller before scrubbing if it might
/// contain a token).
///
/// This intentionally errs on the side of dropping too much rather than too
/// little. False positives (e.g. a column literally called `password_hint`)
/// will lose readable values; the tradeoff is worth it for compliance.
enum PIIScrubber {
    /// Substrings checked case-insensitively against each key.
    static let denyList: Set<String> = [
        "password",
        "passwd",
        "secret",
        "token",
        "apikey",
        "api_key",
        "authorization",
        "auth",
        "bearer",
        "session",
        "cookie",
        "x-api-key",
        "credit_card",
        "creditcard",
        "card_number",
        "cvv",
        "ssn",
    ]

    /// Returns a deep-cleaned copy of `value`. Safe to pass any JSON-derived
    /// structure (dict / array / string / number / bool / null).
    static func scrub(_ value: Any?) -> Any? {
        guard let value else { return nil }

        if let dict = value as? [String: Any] {
            var cleaned: [String: Any] = [:]
            cleaned.reserveCapacity(dict.count)
            for (key, child) in dict {
                if isSensitive(key) {
                    cleaned[key] = "<redacted>"
                } else if let scrubbedChild = scrub(child) {
                    cleaned[key] = scrubbedChild
                }
            }
            return cleaned
        }

        if let array = value as? [Any] {
            return array.compactMap { scrub($0) }
        }

        return value
    }

    /// Convenience overload for `[String: Any]` so callers don't lose the type.
    static func scrub(_ dict: [String: Any]?) -> [String: Any]? {
        guard let dict else { return nil }
        return scrub(dict as Any) as? [String: Any]
    }

    private static func isSensitive(_ key: String) -> Bool {
        let lower = key.lowercased()
        for deny in denyList {
            if lower.contains(deny) { return true }
        }
        return false
    }
}
