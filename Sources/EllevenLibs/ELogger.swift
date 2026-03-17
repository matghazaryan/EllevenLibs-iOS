import Foundation
import os.log

/// A simple tagged logger for consistent logging across your apps.
///
/// Usage:
/// ```swift
/// let logger = ELogger(tag: "Network")
/// logger.debug("Request started")
/// logger.info("Response received")
/// logger.warning("Slow response: 3.2s")
/// logger.error("Request failed: timeout")
/// ```
public final class ELogger {
    private let tag: String
    private let osLog: OSLog

    public init(tag: String) {
        self.tag = tag
        self.osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "EllevenLibs", category: tag)
    }

    public func debug(_ message: String) {
        os_log("[%{public}@] %{public}@", log: osLog, type: .debug, tag, message)
    }

    public func info(_ message: String) {
        os_log("[%{public}@] %{public}@", log: osLog, type: .info, tag, message)
    }

    public func warning(_ message: String) {
        os_log("[%{public}@] ⚠️ %{public}@", log: osLog, type: .default, tag, message)
    }

    public func error(_ message: String) {
        os_log("[%{public}@] ❌ %{public}@", log: osLog, type: .error, tag, message)
    }
}
