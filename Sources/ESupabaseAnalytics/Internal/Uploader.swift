import Foundation

/// POSTs event batches to Supabase PostgREST.
///
/// Matches the plain `URLSession` + `JSONSerialization` shape used by
/// `EIntelligence` so this library stays dependency-free.
struct Uploader {
    let config: ESupabaseAnalyticsConfig
    /// Auth token (user JWT). Falls back to the anon key when nil.
    var authToken: String?

    func upload(_ events: [[String: Any]]) async throws {
        guard !events.isEmpty else { return }

        let endpoint = config.supabaseUrl
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
            .appendingPathComponent(config.tableName)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authToken ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.normalizeBatchKeys(events))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ESupabaseAnalyticsError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ESupabaseAnalyticsError.network("no HTTP response")
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw ESupabaseAnalyticsError.server(http.statusCode, body)
        }
    }

    // PostgREST bulk insert (PGRST102) requires every row in the array to have
    // the same keys. Optional columns (user_id, screen_name, properties, ...)
    // are added per-event, so a batch can mix shapes — fill the gaps with
    // NSNull so JSONSerialization writes `null`.
    static func normalizeBatchKeys(_ events: [[String: Any]]) -> [[String: Any]] {
        guard events.count > 1 else { return events }
        var keys = Set<String>()
        for ev in events { keys.formUnion(ev.keys) }
        return events.map { ev in
            var row = ev
            for k in keys where row[k] == nil {
                row[k] = NSNull()
            }
            return row
        }
    }
}
