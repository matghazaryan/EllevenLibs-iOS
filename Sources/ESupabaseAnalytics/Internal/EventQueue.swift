import Foundation

/// Disk-backed FIFO queue of event dictionaries.
///
/// Stored as a single JSON array in `UserDefaults` under `storageKey` (default
/// `ESupabaseAnalytics_queue`). The sister observability recorders
/// (`ESupabaseNetworkRecorder`, `ESupabaseRevenueRecorder`,
/// `ESupabaseCrashReporter`) instantiate their own EventQueue with a distinct
/// key so the four streams don't clobber each other.
///
/// All access is serialized through a private dispatch queue so writes from the
/// public `track(...)` path and reads from the flush loop can't race.
final class EventQueue {
    private let storageKey: String
    private let queue: DispatchQueue
    private let defaults: UserDefaults

    init(storageKey: String = "ESupabaseAnalytics_queue", defaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        // Each queue gets its own serial dispatch queue keyed by the storage key
        // so flushes on one queue don't head-of-line block the others.
        self.queue = DispatchQueue(label: "com.ellevenstudio.esupabaseanalytics.queue.\(storageKey)", qos: .utility)
        self.defaults = defaults
    }

    func enqueue(_ event: [String: Any]) {
        queue.async {
            var current = self.loadLocked()
            current.append(event)
            self.saveLocked(current)
        }
    }

    /// Atomically returns up to `limit` events and pins them for removal via `remove(count:)`.
    func snapshot(limit: Int = 200) -> [[String: Any]] {
        queue.sync {
            let current = loadLocked()
            if current.count <= limit { return current }
            return Array(current.prefix(limit))
        }
    }

    /// Drops the first `count` events from the queue (the batch we just uploaded).
    func remove(count: Int) {
        guard count > 0 else { return }
        queue.async {
            var current = self.loadLocked()
            let toRemove = min(count, current.count)
            if toRemove == current.count {
                current.removeAll()
            } else {
                current.removeFirst(toRemove)
            }
            self.saveLocked(current)
        }
    }

    func clear() {
        queue.async {
            self.defaults.removeObject(forKey: self.storageKey)
        }
    }

    func count() -> Int {
        queue.sync { loadLocked().count }
    }

    // MARK: - Private (must be called inside `queue`)

    private func loadLocked() -> [[String: Any]] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    private func saveLocked(_ events: [[String: Any]]) {
        if events.isEmpty {
            defaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: events) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
