import Foundation
import Darwin
#if canImport(UIKit)
import UIKit
#endif

/// Captures uncaught Objective-C exceptions, unhandled signals (SIGSEGV /
/// SIGABRT / SIGBUS / SIGILL / SIGFPE / SIGPIPE), and explicitly-reported
/// errors to the `crashes` table for the same Supabase project that
/// `ESupabaseAnalytics.shared` is configured against.
///
/// **Lifecycle**
///
/// 1. Consumer calls `ESupabaseCrashReporter.shared.install()` once at app
///    startup (after `ESupabaseAnalytics.shared.configure(...)`).
/// 2. `install()` first scans the on-disk crash directory and uploads any
///    pending records from the previous run (the *previous* crash is what
///    we're shipping — we couldn't upload it during the crash itself).
/// 3. `install()` registers an `NSSetUncaughtExceptionHandler` and POSIX
///    `signal()` handlers. When a crash hits, the handlers serialize a JSON
///    record to `~/Library/Caches/ESupabaseAnalytics/pending_crashes/` and
///    chain to the prior handler (so other crash reporters in the app still
///    fire).
/// 4. On the next launch, step 2 picks up the file, ships it, deletes it.
///
/// **Caveats**
///
/// - Signal handlers must use only async-signal-safe functions. We use
///   `write()` to a pre-opened file descriptor with a minimal preformatted
///   record. `Foundation` (`JSONSerialization`, `FileManager`) is **not**
///   async-signal-safe and is only used by the NSException path, which runs
///   *before* the process is terminated and still has full Foundation access.
/// - This is best-effort capture, not a substitute for KSCrash / PLCrashReporter.
///   Hard SIGSEGVs may sometimes leave a corrupt record. That's fine — most
///   real-world crashes are catchable Swift / NSException errors that we get
///   cleanly.
/// - Call `report(...)` directly to log a non-fatal error (e.g. inside a
///   `catch` block) without triggering process termination.
@MainActor
public final class ESupabaseCrashReporter {
    public static let shared = ESupabaseCrashReporter()

    public private(set) var isInstalled = false
    public private(set) var isEnabled = true

    private let queue = EventQueue(storageKey: "ESupabaseAnalytics_crash_queue")
    private var flushTask: Task<Void, Never>?

    private init() {}

    // MARK: - Public API

    /// Install crash handlers and ship any pending crash from the previous
    /// run. Idempotent — safe to call multiple times.
    public func install() {
        guard !isInstalled else { return }
        isInstalled = true

        Self.ensureCrashDirectory()
        flushPendingCrashes()
        installNSExceptionHandler()
        installSignalHandlers()
        ensureFlushLoop()
    }

    /// Report a non-fatal error — runs the same upload path as a crash but
    /// without terminating the process. Use inside `catch` blocks where you
    /// want analytics on the failure but the app keeps running.
    ///
    /// - Parameters:
    ///   - error: The error to report. Use `kind = "react_error_boundary"`-style
    ///     classification via the `kind` parameter for non-NSException sources.
    ///   - kind: Crash classification. Defaults to `"caught_error"`.
    ///   - screen: Last screen the user saw, if known.
    ///   - properties: Free-form context.
    public func report(
        _ error: Error,
        kind: String = "caught_error",
        screen: String? = nil,
        properties: [String: Any]? = nil
    ) {
        guard isEnabled else { return }
        let record = Self.buildRecord(
            kind: kind,
            isFatal: false,
            exceptionClass: String(describing: type(of: error)),
            exceptionMessage: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            screen: screen,
            sessionId: ESupabaseAnalytics.shared.sharedReadSessionWithoutTouch(),
            userId: ESupabaseAnalytics.shared.sharedUserId,
            properties: properties
        )
        queue.enqueue(record)
        ensureFlushLoop()
    }

    /// Force an upload attempt now.
    public func flush() async {
        await performFlush()
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            flushTask?.cancel()
            flushTask = nil
            queue.clear()
        }
    }

    // MARK: - On-disk persistence (used by signal + NSException handlers)

    nonisolated private static let crashDirURL: URL = {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDir.appendingPathComponent("ESupabaseAnalytics/pending_crashes", isDirectory: true)
    }()

    /// Pre-resolved C string of the crash directory path so the signal handler
    /// (which can't allocate / can't call Foundation) has a path to write to.
    nonisolated(unsafe) private static let crashDirCString: UnsafeMutablePointer<CChar> = {
        let path = crashDirURL.path
        let cstr = strdup(path)!
        return cstr
    }()

    nonisolated private static func ensureCrashDirectory() {
        try? FileManager.default.createDirectory(at: crashDirURL, withIntermediateDirectories: true)
    }

    /// Build a JSON-serializable crash record. Safe to call from the main
    /// thread (uses Foundation). The signal handler path can't use this — it
    /// writes a minimal preformatted string instead via `signalHandler(_:)`.
    nonisolated private static func buildRecord(
        kind: String,
        isFatal: Bool,
        exceptionClass: String?,
        exceptionMessage: String?,
        stackTrace: String?,
        screen: String?,
        sessionId: String?,
        userId: String?,
        properties: [String: Any]?
    ) -> [String: Any] {
        let ctx = DeviceContext.current
        var row: [String: Any] = [
            "occurred_at": ISO8601DateFormatter.shared.string(from: Date()),
            "device_id": ctx.deviceId,
            "platform": "ios",
            "kind": kind,
            "is_fatal": isFatal,
            "crash_signature": signature(class: exceptionClass, kind: kind, stackTrace: stackTrace),
        ]
        if let v = ctx.appVersion { row["app_version"] = v } else { row["app_version"] = "unknown" }
        if let b = ctx.appBuild { row["app_build"] = b } else { row["app_build"] = "unknown" }
        row["os_version"] = ctx.osVersion
        row["device_model"] = ctx.deviceModel
        if let sessionId { row["session_id"] = sessionId }
        if let userId { row["user_id"] = userId }
        if let exceptionClass { row["exception_class"] = exceptionClass }
        if let exceptionMessage { row["exception_message"] = exceptionMessage }
        if let stackTrace { row["stack_trace"] = stackTrace }
        if let screen { row["screen"] = screen }
        if let extra = PIIScrubber.scrub(properties), !extra.isEmpty {
            row["properties"] = extra
        }
        return row
    }

    /// Stable hash for grouping identical crashes.
    nonisolated private static func signature(class cls: String?, kind: String, stackTrace: String?) -> String {
        // Hash exceptionClass + kind + the first 3 stack frames (which usually
        // identify the crash site uniquely). Truncating to 3 frames means the
        // same bug from different call paths still groups together.
        let topFrames = stackTrace?
            .split(separator: "\n")
            .prefix(3)
            .joined(separator: "|") ?? ""
        let raw = "\(cls ?? "")|\(kind)|\(topFrames)"
        var h: UInt64 = 0xcbf29ce484222325
        for byte in raw.utf8 {
            h ^= UInt64(byte)
            h &*= 0x100000001b3
        }
        return String(format: "%016llx", h)
    }

    /// Persist a crash record to disk synchronously. Used by the NSException
    /// handler — Foundation is safe there because the process hasn't aborted yet.
    nonisolated private static func persistRecordToDisk(_ record: [String: Any]) {
        ensureCrashDirectory()
        let filename = "crash_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString).json"
        let url = crashDirURL.appendingPathComponent(filename)
        guard let data = try? JSONSerialization.data(withJSONObject: record) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Read every pending crash file from disk, enqueue them, delete the files.
    /// Called once on `install()` to ship the crash from the previous run.
    private func flushPendingCrashes() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: Self.crashDirURL, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                queue.enqueue(record)
            }
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Handlers

    /// Storage for the previous handler so we can chain to it (other crash
    /// reporters in the same app still fire).
    nonisolated(unsafe) private static var previousNSExceptionHandler: (@convention(c) (NSException) -> Void)?

    private func installNSExceptionHandler() {
        Self.previousNSExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            // Signal handlers can't capture instance state — read fresh from
            // the singleton here (we're on the main thread, Foundation is OK).
            let record = ESupabaseCrashReporter.buildRecord(
                kind: "nsexception",
                isFatal: true,
                exceptionClass: exception.name.rawValue,
                exceptionMessage: exception.reason,
                stackTrace: exception.callStackSymbols.joined(separator: "\n"),
                screen: nil,
                sessionId: nil,        // not safe to call into MainActor from here
                userId: nil,
                properties: ["user_info": exception.userInfo as Any]
            )
            ESupabaseCrashReporter.persistRecordToDisk(record)

            // Chain to the previous handler so we don't break other reporters
            // (Crashlytics, Sentry, etc.) installed in the same app.
            ESupabaseCrashReporter.previousNSExceptionHandler?(exception)
        }
    }

    private func installSignalHandlers() {
        let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGPIPE]
        for sig in signals {
            signal(sig) { signum in
                // ASYNC-SIGNAL-SAFE ZONE — only use functions from sigaction(2) man page.
                // No malloc, no Foundation, no Swift collections. Just write a
                // preformatted minimal record using POSIX `write` to a fresh fd.
                // Qualify with explicit class name (not `Self`) so the C function
                // pointer doesn't try to capture dynamic Self type.
                ESupabaseCrashReporter.writeSignalRecord(signum: signum)
                // Re-raise with default handler so the OS gets the crash report
                // and the process actually dies (otherwise we'd loop).
                signal(signum, SIG_DFL)
                raise(signum)
            }
        }
    }

    /// ASYNC-SIGNAL-SAFE: write a minimal JSON record to a uniquely-named file
    /// in the crash directory. Uses only POSIX write/open/close/snprintf.
    nonisolated private static func writeSignalRecord(signum: Int32) {
        // Build filename: <crashDir>/crash_signal_<timestamp>_<signum>.json
        var filenameBuf = [CChar](repeating: 0, count: 1024)
        let ts = time(nil)
        _ = strncpy(&filenameBuf, crashDirCString, 512)
        let dirLen = strnlen(crashDirCString, 512)
        // append "/crash_signal_<ts>_<signum>.json" via snprintf
        let suffixBytes = Array("/crash_signal_\(ts)_\(signum).json".utf8CString)
        let remaining = filenameBuf.count - dirLen - 1
        let toCopy = min(suffixBytes.count, remaining)
        suffixBytes.prefix(toCopy).enumerated().forEach { i, b in
            filenameBuf[dirLen + i] = b
        }

        let fd = open(filenameBuf, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        defer { close(fd) }

        // Minimal JSON — no escaping needed because all values are fixed.
        // Use signature = "signal_<signum>" so identical signals group.
        let body =
            "{\"kind\":\"signal\",\"is_fatal\":true," +
            "\"signal\":\(signum)," +
            "\"occurred_at_unix\":\(ts)," +
            "\"crash_signature\":\"signal_\(signum)\"," +
            "\"_needs_enrichment\":true}"
        body.withCString { ptr in
            let len = strlen(ptr)
            _ = write(fd, ptr, len)
        }
    }

    // MARK: - Flush loop

    private func ensureFlushLoop() {
        guard flushTask == nil, isEnabled, let interval = ESupabaseAnalytics.shared.sharedConfig?.flushInterval else { return }
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

        // Some records (signal-handler ones) are minimal — enrich them with
        // device context and identity at upload time, since that wasn't safe
        // to capture inside the signal handler.
        let enriched = batch.map { record -> [String: Any] in
            guard record["_needs_enrichment"] as? Bool == true else { return record }
            var enriched = record
            enriched.removeValue(forKey: "_needs_enrichment")
            let ctx = DeviceContext.current
            enriched["device_id"] = ctx.deviceId
            enriched["platform"] = "ios"
            enriched["app_version"] = ctx.appVersion ?? "unknown"
            enriched["app_build"] = ctx.appBuild ?? "unknown"
            enriched["os_version"] = ctx.osVersion
            enriched["device_model"] = ctx.deviceModel
            // session_id from peek — this is the session that crashed (last known).
            if let sid = ESupabaseAnalytics.shared.sharedReadSessionWithoutTouch() {
                enriched["session_id"] = sid
            }
            if let uid = ESupabaseAnalytics.shared.sharedUserId {
                enriched["user_id"] = uid
            }
            // Convert occurred_at_unix to ISO timestamp.
            if let ts = enriched["occurred_at_unix"] as? Int {
                let date = Date(timeIntervalSince1970: TimeInterval(ts))
                enriched["occurred_at"] = ISO8601DateFormatter.shared.string(from: date)
                enriched.removeValue(forKey: "occurred_at_unix")
            }
            return enriched
        }

        let crashConfig = ESupabaseAnalyticsConfig(
            supabaseUrl: config.supabaseUrl,
            anonKey: config.anonKey,
            tableName: "crashes",
            flushInterval: config.flushInterval,
            sessionTimeout: config.sessionTimeout
        )
        let uploader = Uploader(config: crashConfig, authToken: ESupabaseAnalytics.shared.sharedAuthToken)

        do {
            try await uploader.upload(enriched)
            queue.remove(count: batch.count)
        } catch {
            #if DEBUG
            print("[ESupabaseCrashReporter] flush failed: \(error.localizedDescription)")
            #endif
        }
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
