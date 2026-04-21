import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight analytics client that writes events to a Supabase Postgres table
/// via PostgREST. Replaces Firebase Analytics for simple use cases.
///
/// - Events are cached on disk in `UserDefaults`.
/// - A background task flushes the queue every `flushInterval` seconds (default 5).
/// - Successfully uploaded events are removed from the local cache. Failed batches
///   stay cached and retry on the next tick.
/// - Works without authentication. When the consumer calls `setUserId(_:)` or
///   `setAuthToken(_:)` the values are attached to subsequent events.
///
/// Usage:
///     ESupabaseAnalytics.shared.configure(
///         ESupabaseAnalyticsConfig(
///             supabaseUrl: URL(string: "https://xyz.supabase.co")!,
///             anonKey: "..."
///         )
///     )
///     ESupabaseAnalytics.shared.setUserId("user_123")
///     ESupabaseAnalytics.shared.track("button_tap", properties: ["name": "subscribe"])
///     ESupabaseAnalytics.shared.trackScreen("Home")
@MainActor
public final class ESupabaseAnalytics {
    public static let shared = ESupabaseAnalytics()

    // MARK: - State

    public private(set) var isConfigured = false
    public private(set) var isEnabled = true

    private var config: ESupabaseAnalyticsConfig?
    private var uploader: Uploader?
    private var session: SessionManager?
    private let queue = EventQueue()
    private var flushTask: Task<Void, Never>?

    private var userId: String?
    private var authToken: String?

    #if canImport(UIKit)
    private var lifecycleObservers: [NSObjectProtocol] = []
    #endif

    private init() {}

    // MARK: - Configure

    /// Configure with a Supabase URL + anon key. MUST be called before any `track`.
    /// Safe to call multiple times — later calls replace the config and restart the flush loop.
    public func configure(_ config: ESupabaseAnalyticsConfig) {
        self.config = config
        self.uploader = Uploader(config: config, authToken: authToken)
        let session = SessionManager(timeout: config.sessionTimeout)
        self.session = session
        self.isConfigured = true

        installLifecycleObservers()
        handleForeground()
        startFlushLoop()
    }

    // MARK: - Identity

    /// Attach a `user_id` to subsequent events. Pass `nil` to clear.
    public func setUserId(_ userId: String?) {
        self.userId = userId
    }

    /// Supply a Supabase user JWT. When set, it replaces the anon key in the
    /// `Authorization` header so row-level-security policies that check `auth.uid()`
    /// work. Pass `nil` to fall back to the anon key.
    public func setAuthToken(_ token: String?) {
        self.authToken = token
        self.uploader?.authToken = token
    }

    // MARK: - Tracking

    /// Track a custom event.
    /// - Parameters:
    ///   - name: Event name (e.g. `"button_tap"`, `"purchase_completed"`).
    ///   - properties: Free-form values. Non-JSON-serializable values are dropped.
    public func track(_ name: String, properties: [String: Any]? = nil) {
        guard isEnabled, let config, let session else { return }
        _ = config // silence unused warning in no-op branches

        let now = Date()
        if let roll = session.rollIfNeeded(now: now) {
            enqueueInternal(
                name: "session_end",
                at: now,
                sessionId: roll.previousSessionId,
                screenName: nil,
                extraProperties: ["duration_ms": Int(roll.previousDurationSeconds * 1000)]
            )
            enqueueInternal(
                name: "session_start",
                at: now,
                sessionId: roll.newSessionId,
                screenName: nil,
                extraProperties: nil
            )
        }

        let sessionId = session.currentSessionId(now: now)

        if session.touchDay(now: now) {
            enqueueInternal(
                name: "daily_open",
                at: now,
                sessionId: sessionId,
                screenName: nil,
                extraProperties: nil
            )
        }

        enqueueInternal(
            name: name,
            at: now,
            sessionId: sessionId,
            screenName: properties?["screen_name"] as? String,
            extraProperties: properties
        )

        session.touchEvent(at: now)
    }

    /// Convenience for screen-view tracking.
    /// Emits `screen_view` with `screen_name` set.
    public func trackScreen(_ name: String, properties: [String: Any]? = nil) {
        var merged = properties ?? [:]
        merged["screen_name"] = name
        track("screen_view", properties: merged)
    }

    /// Force an upload attempt now (useful for tests and critical moments like purchase).
    public func flush() async {
        await performFlush()
    }

    /// Turn analytics on/off. Turning off cancels the flush loop and wipes the local cache.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            startFlushLoop()
        } else {
            flushTask?.cancel()
            flushTask = nil
            queue.clear()
        }
    }

    // MARK: - Internal enqueue

    private func enqueueInternal(
        name: String,
        at date: Date,
        sessionId: String,
        screenName: String?,
        extraProperties: [String: Any]?
    ) {
        let ctx = DeviceContext.current

        var event: [String: Any] = [
            "event_name": name,
            "occurred_at": ISO8601DateFormatter.shared.string(from: date),
            "device_id": ctx.deviceId,
            "session_id": sessionId,
            "platform": "ios",
            "os_version": ctx.osVersion,
            "device_model": ctx.deviceModel,
            "locale": ctx.locale,
            "timezone": ctx.timezone,
            "is_debug": ctx.isDebug,
        ]
        if let v = ctx.appVersion { event["app_version"] = v }
        if let b = ctx.appBuild { event["app_build"] = b }
        if let icloud = ctx.iCloudId { event["icloud_id"] = icloud }
        if let userId { event["user_id"] = userId }
        if let screenName { event["screen_name"] = screenName }

        if let extraProperties, !extraProperties.isEmpty {
            // Keep only JSON-serializable custom keys and strip any that collide with top-level columns.
            let reserved: Set<String> = [
                "event_name", "occurred_at", "device_id", "session_id", "platform",
                "os_version", "device_model", "locale", "timezone", "is_debug",
                "app_version", "app_build", "icloud_id", "user_id", "screen_name",
            ]
            var clean: [String: Any] = [:]
            for (k, v) in extraProperties where !reserved.contains(k) {
                if JSONSerialization.isValidJSONObject([k: v]) {
                    clean[k] = v
                }
            }
            if !clean.isEmpty {
                event["properties"] = clean
            }
        }

        queue.enqueue(event)
    }

    // MARK: - Flush loop

    private func startFlushLoop() {
        flushTask?.cancel()
        guard isEnabled, let interval = config?.flushInterval else { return }
        let nanos = UInt64(max(1, interval) * 1_000_000_000)

        flushTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanos)
                guard let self else { return }
                await self.performFlush()
            }
        }
    }

    private func performFlush() async {
        guard let uploader else { return }
        let batch = queue.snapshot()
        guard !batch.isEmpty else { return }
        do {
            try await uploader.upload(batch)
            queue.remove(count: batch.count)
        } catch {
            // Leave the batch in the queue — next tick retries.
            #if DEBUG
            print("[ESupabaseAnalytics] flush failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Lifecycle

    private func installLifecycleObservers() {
        #if canImport(UIKit)
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers.removeAll()

        let foreground = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleForeground() }
        }
        let background = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleBackground() }
        }
        lifecycleObservers = [foreground, background]
        #endif
    }

    private func handleForeground() {
        guard isEnabled, let session else { return }
        let now = Date()
        if let roll = session.rollIfNeeded(now: now) {
            enqueueInternal(
                name: "session_end",
                at: now,
                sessionId: roll.previousSessionId,
                screenName: nil,
                extraProperties: ["duration_ms": Int(roll.previousDurationSeconds * 1000)]
            )
            enqueueInternal(
                name: "session_start",
                at: now,
                sessionId: roll.newSessionId,
                screenName: nil,
                extraProperties: nil
            )
        } else {
            // Brand-new install / first configure of the process — emit a session_start
            // only if this is truly the first event for the current session.
            let sessionId = session.currentSessionId(now: now)
            if queue.count() == 0 {
                enqueueInternal(
                    name: "session_start",
                    at: now,
                    sessionId: sessionId,
                    screenName: nil,
                    extraProperties: nil
                )
            }
        }
        session.touchEvent(at: now)
    }

    private func handleBackground() {
        guard isEnabled, let session else { return }
        let now = Date()
        if let snapshot = session.snapshotForBackgrounding(now: now) {
            enqueueInternal(
                name: "session_end",
                at: now,
                sessionId: snapshot.sessionId,
                screenName: nil,
                extraProperties: ["duration_ms": Int(snapshot.durationSeconds * 1000)]
            )
        }
        session.touchEvent(at: now)
    }
}

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
