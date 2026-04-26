import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Logs every HTTP / Edge Function call to the `network_requests` table for
/// the same Supabase project that `ESupabaseAnalytics.shared` is configured
/// against. Reads device + session + identity context from
/// `ESupabaseAnalytics.shared` so it doesn't need its own configure call —
/// the consumer just calls `ESupabaseAnalytics.shared.configure(...)` once,
/// then logs requests via `ESupabaseNetworkRecorder.shared.log(...)`.
///
/// The record-on-success vs record-on-error policy is up to the caller: this
/// API records *whatever you log*. The recommended consumer pattern is to
/// always call `log(...)` after every meaningful HTTP call, but pass
/// `requestBody` / `responseBody` only on failure (or sample 1% of successes)
/// so the table doesn't balloon.
///
/// Bodies are PII-scrubbed via `PIIScrubber` before insert.
@MainActor
public final class ESupabaseNetworkRecorder {
    public static let shared = ESupabaseNetworkRecorder()

    public private(set) var isEnabled = true

    private let queue = EventQueue(storageKey: "ESupabaseAnalytics_network_queue")
    private var flushTask: Task<Void, Never>?
    private var lifecycleInstalled = false

    #if canImport(UIKit)
    private var lifecycleObservers: [NSObjectProtocol] = []
    #endif

    private init() {}

    // MARK: - Public API

    /// Log a network request. Call this from your HTTP wrapper / interceptor
    /// after the response (or transport failure) lands.
    ///
    /// - Parameters:
    ///   - endpoint: Path or full URL (e.g. `"/functions/v1/submit-prediction-v3"`).
    ///   - httpMethod: `"GET"` / `"POST"` / etc.
    ///   - httpStatus: HTTP status code, or `nil` for a transport failure.
    ///   - durationMs: Wall-clock duration of the call, in milliseconds.
    ///   - screen: Last screen the user saw when the call fired (read from your screen tracker).
    ///   - requestSizeBytes: Optional size of the request body.
    ///   - requestBody: Optional request body (recommended: only pass on failures).
    ///   - responseSizeBytes: Optional size of the response body.
    ///   - responseBody: Optional response body (recommended: only pass on failures).
    ///   - errorMessage: Human-readable error string for transport failures or non-2xx responses.
    ///   - errorSignature: Stable hash for grouping identical failures. If `nil`, one is computed
    ///     from `endpoint + httpStatus`.
    ///   - properties: Free-form context.
    public func log(
        endpoint: String,
        httpMethod: String,
        httpStatus: Int?,
        durationMs: Int,
        screen: String? = nil,
        requestSizeBytes: Int? = nil,
        requestBody: [String: Any]? = nil,
        responseSizeBytes: Int? = nil,
        responseBody: [String: Any]? = nil,
        errorMessage: String? = nil,
        errorSignature: String? = nil,
        properties: [String: Any]? = nil
    ) {
        guard isEnabled, let config = ESupabaseAnalytics.shared.sharedConfig else { return }
        _ = config

        let now = Date()
        let sessionId = ESupabaseAnalytics.shared.sharedTouchSession(at: now)

        let isError = httpStatus.map { $0 >= 400 } ?? true
        let signature = errorSignature ?? (isError ? makeSignature(endpoint: endpoint, httpStatus: httpStatus) : nil)

        let ctx = DeviceContext.current

        var row: [String: Any] = [
            "occurred_at": ISO8601DateFormatter.shared.string(from: now),
            "device_id": ctx.deviceId,
            "platform": "ios",
            "endpoint": endpoint,
            "http_method": httpMethod.uppercased(),
            "duration_ms": durationMs,
        ]
        if let sessionId { row["session_id"] = sessionId }
        if let userId = ESupabaseAnalytics.shared.sharedUserId { row["user_id"] = userId }
        if let v = ctx.appVersion { row["app_version"] = v }
        if let b = ctx.appBuild { row["app_build"] = b }
        row["os_version"] = ctx.osVersion
        if let screen { row["screen"] = screen }
        if let httpStatus { row["http_status"] = httpStatus }
        if let requestSizeBytes { row["request_size_bytes"] = requestSizeBytes }
        if let responseSizeBytes { row["response_size_bytes"] = responseSizeBytes }
        if let scrubbed = PIIScrubber.scrub(requestBody), !scrubbed.isEmpty {
            row["request_body"] = scrubbed
        }
        if let scrubbed = PIIScrubber.scrub(responseBody), !scrubbed.isEmpty {
            row["response_body"] = scrubbed
        }
        if let errorMessage { row["error_message"] = errorMessage }
        if let signature { row["error_signature"] = signature }

        if let extra = PIIScrubber.scrub(properties), !extra.isEmpty {
            row["properties"] = extra
        }

        queue.enqueue(row)
        ensureFlushLoop()
    }

    /// Force an upload attempt now (useful for tests + critical moments).
    public func flush() async {
        await performFlush()
    }

    /// Turn the recorder on/off. Off cancels the flush loop and wipes the local cache.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            ensureFlushLoop()
        } else {
            flushTask?.cancel()
            flushTask = nil
            queue.clear()
        }
    }

    // MARK: - Internals

    private func makeSignature(endpoint: String, httpStatus: Int?) -> String {
        let raw = "\(endpoint)|\(httpStatus.map(String.init) ?? "no-response")"
        // Cheap stable hash; SipHash-style via Swift's hasher would be process-local,
        // so we go with a portable FNV-1a 64-bit fold (truncated to 12 hex chars)
        // so the signature is comparable across app launches and devices.
        var h: UInt64 = 0xcbf29ce484222325
        for byte in raw.utf8 {
            h ^= UInt64(byte)
            h &*= 0x100000001b3
        }
        return String(format: "%012llx", h)
    }

    private func ensureFlushLoop() {
        guard flushTask == nil, isEnabled, let interval = ESupabaseAnalytics.shared.sharedConfig?.flushInterval else { return }
        installLifecycleObserversIfNeeded()
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
        guard let config = ESupabaseAnalytics.shared.sharedConfig else { return }
        let batch = queue.snapshot()
        guard !batch.isEmpty else { return }

        let networkConfig = ESupabaseAnalyticsConfig(
            supabaseUrl: config.supabaseUrl,
            anonKey: config.anonKey,
            tableName: "network_requests",
            flushInterval: config.flushInterval,
            sessionTimeout: config.sessionTimeout
        )
        let uploader = Uploader(config: networkConfig, authToken: ESupabaseAnalytics.shared.sharedAuthToken)

        do {
            try await uploader.upload(batch)
            queue.remove(count: batch.count)
        } catch {
            // Leave the batch in the queue — next tick retries.
            #if DEBUG
            print("[ESupabaseNetworkRecorder] flush failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func installLifecycleObserversIfNeeded() {
        #if canImport(UIKit)
        guard !lifecycleInstalled else { return }
        lifecycleInstalled = true

        let bg = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.flushTask?.cancel()
                self?.flushTask = nil
                await self?.performFlush()
            }
        }
        let fg = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.ensureFlushLoop() }
        }
        lifecycleObservers = [bg, fg]
        #endif
    }
}

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private extension Dictionary where Key == String {
    var isEmpty: Bool { count == 0 }
}
