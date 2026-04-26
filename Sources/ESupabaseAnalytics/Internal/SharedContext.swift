import Foundation

/// Internal bridge that lets the sister recorders
/// (`ESupabaseNetworkRecorder`, `ESupabaseCrashReporter`,
/// `ESupabaseRevenueRecorder`) read shared state from the main
/// `ESupabaseAnalytics` singleton without duplicating configuration plumbing.
///
/// The consumer app calls `ESupabaseAnalytics.shared.configure(...)` once.
/// Identity changes flow through `setUserId(_:)` / `setAuthToken(_:)`. The
/// recorders read the latest values via these accessors when they build a row,
/// so they always reflect current identity and don't need their own configure
/// call or state copies.
extension ESupabaseAnalytics {
    /// The Supabase URL + anon key + flush interval the consumer configured.
    /// `nil` when `configure(...)` has not been called yet — recorders should
    /// no-op in that case.
    var sharedConfig: ESupabaseAnalyticsConfig? { config }

    /// Current `user_id` to attach to rows. `nil` for anonymous traffic.
    var sharedUserId: String? { userId }

    /// Current Supabase user JWT for the `Authorization` header. Falls back to
    /// the anon key inside the uploader when `nil`.
    var sharedAuthToken: String? { authToken }

    /// Current session id (UUID string), starting / refreshing the session if
    /// needed. Touches `lastEventAt` so recorder activity (network calls,
    /// purchases) keeps the session alive — same semantics as a `track(...)`.
    func sharedTouchSession(at date: Date = Date()) -> String? {
        guard let session else { return nil }
        return session.currentSessionId(now: date)
    }

    /// Same as `sharedTouchSession` but does NOT touch `lastEventAt`. Used by
    /// the crash reporter when capturing a crash for an *already-ending*
    /// session — we want the crash tagged with the in-flight session id, not
    /// to extend it.
    func sharedReadSessionWithoutTouch() -> String? {
        guard let session else { return nil }
        return session.peekSessionId()
    }
}
