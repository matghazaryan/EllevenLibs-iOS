import Foundation

/// Tracks the current session id, session idle timeout, and per-calendar-day first-open dedup.
///
/// A session rolls when `sessionTimeout` has elapsed since the last tracked event.
/// On each roll the caller receives a `.rolled` signal with the previous session's
/// duration so it can emit `session_end` and `session_start` events.
///
/// The `touchDay()` API returns `true` exactly once per calendar day so the caller
/// can emit a `daily_open` event and compute a days-visited count server-side.
final class SessionManager {
    private enum Key {
        static let sessionId = "ESupabaseAnalytics_sessionId"
        static let sessionStartedAt = "ESupabaseAnalytics_sessionStartedAt"
        static let lastEventAt = "ESupabaseAnalytics_lastEventAt"
        static let lastOpenDay = "ESupabaseAnalytics_lastOpenDay"
    }

    struct Roll {
        /// Session id being ended.
        let previousSessionId: String
        /// Elapsed time of the session that is ending (seconds).
        let previousDurationSeconds: Double
        /// Session id that just started.
        let newSessionId: String
    }

    private let defaults: UserDefaults
    private let timeout: TimeInterval
    private let dayFormatter: DateFormatter
    private let lock = NSLock()

    init(timeout: TimeInterval, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.timeout = timeout
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = formatter
    }

    /// Current session id, starting a new one if none exists or if the last event
    /// is older than the configured timeout.
    func currentSessionId(now: Date = Date()) -> String {
        lock.lock(); defer { lock.unlock() }
        if let id = defaults.string(forKey: Key.sessionId),
           let last = defaults.object(forKey: Key.lastEventAt) as? Date,
           now.timeIntervalSince(last) < timeout {
            return id
        }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Key.sessionId)
        defaults.set(now, forKey: Key.sessionStartedAt)
        defaults.set(now, forKey: Key.lastEventAt)
        return fresh
    }

    /// If the session has expired, roll it. Returns a `Roll` describing the transition,
    /// or `nil` if the existing session is still valid.
    func rollIfNeeded(now: Date = Date()) -> Roll? {
        lock.lock(); defer { lock.unlock() }

        guard let existing = defaults.string(forKey: Key.sessionId),
              let last = defaults.object(forKey: Key.lastEventAt) as? Date else {
            // No prior session — start a fresh one without emitting a Roll (no prior session_end).
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: Key.sessionId)
            defaults.set(now, forKey: Key.sessionStartedAt)
            defaults.set(now, forKey: Key.lastEventAt)
            return nil
        }

        if now.timeIntervalSince(last) < timeout { return nil }

        let startedAt = (defaults.object(forKey: Key.sessionStartedAt) as? Date) ?? last
        let duration = last.timeIntervalSince(startedAt)
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Key.sessionId)
        defaults.set(now, forKey: Key.sessionStartedAt)
        defaults.set(now, forKey: Key.lastEventAt)
        return Roll(previousSessionId: existing, previousDurationSeconds: max(0, duration), newSessionId: fresh)
    }

    /// Read the in-memory session id without rolling, refreshing, or touching
    /// `lastEventAt`. Returns `nil` if no session has ever been started.
    /// Used by the crash reporter when capturing a crash for a session that's
    /// already ending — we want the crash tagged with the in-flight session id
    /// without artificially extending its lifetime.
    func peekSessionId() -> String? {
        lock.lock(); defer { lock.unlock() }
        return defaults.string(forKey: Key.sessionId)
    }

    /// Call on every tracked event so the idle timer resets.
    func touchEvent(at now: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        defaults.set(now, forKey: Key.lastEventAt)
    }

    /// Returns `true` the first time it's called on a given calendar day.
    func touchDay(now: Date = Date()) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let today = dayFormatter.string(from: now)
        if defaults.string(forKey: Key.lastOpenDay) == today { return false }
        defaults.set(today, forKey: Key.lastOpenDay)
        return true
    }

    /// Returns (sessionId, duration) for the currently open session without rolling it.
    /// Used when the app backgrounds so the caller can emit a `session_end`.
    func snapshotForBackgrounding(now: Date = Date()) -> (sessionId: String, durationSeconds: Double)? {
        lock.lock(); defer { lock.unlock() }
        guard let id = defaults.string(forKey: Key.sessionId),
              let startedAt = defaults.object(forKey: Key.sessionStartedAt) as? Date else {
            return nil
        }
        return (id, max(0, now.timeIntervalSince(startedAt)))
    }
}
