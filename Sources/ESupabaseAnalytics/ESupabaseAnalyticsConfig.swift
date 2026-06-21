import Foundation

/// Configuration for `ESupabaseAnalytics`.
///
/// Pass the same Supabase URL and anon key the consumer app already uses for
/// its own project — events land in the same project, in the `tableName` table
/// (default `"elleven_analytics"`, created by the shipped SQL migration).
///
/// Usage:
///     ESupabaseAnalytics.shared.configure(
///         ESupabaseAnalyticsConfig(
///             supabaseUrl: URL(string: "https://xyz.supabase.co")!,
///             anonKey: "eyJhbGciOi..."
///         )
///     )
public struct ESupabaseAnalyticsConfig {
    public let supabaseUrl: URL
    public let anonKey: String
    public let tableName: String
    public let flushInterval: TimeInterval
    public let sessionTimeout: TimeInterval

    /// - Parameters:
    ///   - supabaseUrl: Base URL of the Supabase project (e.g. `https://xyz.supabase.co`).
    ///   - anonKey: The project's anon/publishable key. User JWTs can be layered on top via `setAuthToken(_:)`.
    ///   - tableName: Target table. Default `"elleven_analytics"`.
    ///   - flushInterval: How often the background flush runs while foregrounded. Default `5` seconds.
    ///   - sessionTimeout: Inactivity after which a new session is rolled. Default `30 * 60` seconds (30 min, matches Firebase Analytics).
    public init(
        supabaseUrl: URL,
        anonKey: String,
        tableName: String = "elleven_analytics",
        flushInterval: TimeInterval = 5,
        sessionTimeout: TimeInterval = 30 * 60
    ) {
        precondition(!anonKey.isEmpty, "[ESupabaseAnalytics] ERROR: anonKey must not be empty.")
        precondition(!tableName.isEmpty, "[ESupabaseAnalytics] ERROR: tableName must not be empty.")
        self.supabaseUrl = supabaseUrl
        self.anonKey = anonKey
        self.tableName = tableName
        self.flushInterval = flushInterval
        self.sessionTimeout = sessionTimeout
    }
}
