import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Records authoritative purchase events to the `revenue` table for the same
/// Supabase project that `ESupabaseAnalytics.shared` is configured against.
///
/// Two write paths feed this table in production:
///   - **Client** (this recorder): writes a `'purchase'` row immediately on
///     successful StoreKit transaction. Has `session_id` so it joins to user
///     behavior in the timeline view.
///   - **Server** (your Edge Function webhooks): writes `'renewal'` /
///     `'refund'` / `'cancellation'` rows. Authoritative for MRR/churn but
///     has no `session_id`. Outside the scope of this recorder.
///
/// The `revenue` table has `unique(external_provider, external_id, kind)` so
/// retries from this recorder *and* your server webhooks are idempotent —
/// duplicate writes are silently dropped by Postgres.
@MainActor
public final class ESupabaseRevenueRecorder {
    public static let shared = ESupabaseRevenueRecorder()

    public private(set) var isEnabled = true

    private let queue = EventQueue(storageKey: "ESupabaseAnalytics_revenue_queue")
    private var flushTask: Task<Void, Never>?
    private var lifecycleInstalled = false

    #if canImport(UIKit)
    private var lifecycleObservers: [NSObjectProtocol] = []
    #endif

    private init() {}

    // MARK: - Public API

    /// Record a purchase / renewal / refund / cancellation event.
    ///
    /// - Parameters:
    ///   - userId: The Supabase user id this purchase belongs to. **Required** —
    ///     anonymous revenue rows are not allowed by the schema.
    ///   - productId: Product identifier from the platform (e.g. `"studio.elleven.app.predictscore.annual"`).
    ///   - productType: `"subscription"` / `"consumable"` / `"non_consumable"`.
    ///   - period: `"monthly"` / `"yearly"` / `"lifetime"`, or `nil` for one-time products.
    ///   - amountCents: Price in **integer cents** of the local currency (e.g. `299` for $2.99). Never floats.
    ///   - currency: ISO 4217 code (e.g. `"USD"`, `"EUR"`).
    ///   - kind: `"purchase"` / `"renewal"` / `"refund"` / `"upgrade"` / `"downgrade"`
    ///     / `"cancellation"` / `"restore"` / `"trial_start"` / `"trial_convert"`.
    ///   - status: `"succeeded"` (default) / `"pending"` / `"failed"`.
    ///   - externalProvider: `"apple"` for StoreKit, `"google"` for Play Billing,
    ///     `"stripe"` for web Stripe Checkout.
    ///   - externalId: Provider's authoritative ID. Stripe charge id /
    ///     Apple `original_transaction_id` / Google `purchase_token`.
    ///   - errorCode: Optional error code on failed purchase.
    ///   - properties: Free-form context (raw transaction JSON, etc.).
    public func recordPurchase(
        userId: String,
        productId: String,
        productType: String = "subscription",
        period: String? = nil,
        amountCents: Int,
        currency: String,
        kind: String = "purchase",
        status: String = "succeeded",
        externalProvider: String = "apple",
        externalId: String,
        errorCode: String? = nil,
        properties: [String: Any]? = nil
    ) {
        guard isEnabled, let config = ESupabaseAnalytics.shared.sharedConfig else { return }
        _ = config

        let now = Date()
        let sessionId = ESupabaseAnalytics.shared.sharedTouchSession(at: now)
        let ctx = DeviceContext.current

        var row: [String: Any] = [
            "occurred_at": ISO8601DateFormatter.shared.string(from: now),
            "device_id": ctx.deviceId,
            "user_id": userId,
            "platform": "ios",
            "product_id": productId,
            "product_type": productType,
            "amount_cents": amountCents,
            "currency": currency,
            "kind": kind,
            "status": status,
            "external_provider": externalProvider,
            "external_id": externalId,
        ]
        if let sessionId { row["session_id"] = sessionId }
        if let v = ctx.appVersion { row["app_version"] = v }
        if let period { row["period"] = period }
        if let errorCode { row["error_code"] = errorCode }

        if let extra = PIIScrubber.scrub(properties), !extra.isEmpty {
            row["properties"] = extra
        }

        queue.enqueue(row)
        ensureFlushLoop()
    }

    /// Force an upload attempt now (useful for tests + critical moments like a purchase that just succeeded).
    public func flush() async {
        await performFlush()
    }

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

        let revenueConfig = ESupabaseAnalyticsConfig(
            supabaseUrl: config.supabaseUrl,
            anonKey: config.anonKey,
            tableName: "elleven_revenue",
            flushInterval: config.flushInterval,
            sessionTimeout: config.sessionTimeout
        )
        let uploader = Uploader(config: revenueConfig, authToken: ESupabaseAnalytics.shared.sharedAuthToken)

        do {
            try await uploader.upload(batch)
            queue.remove(count: batch.count)
        } catch {
            #if DEBUG
            print("[ESupabaseRevenueRecorder] flush failed: \(error.localizedDescription)")
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
