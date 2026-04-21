import Foundation
#if canImport(UIKit)
import UIKit
#endif
import CryptoKit

/// Collects the device + app context that gets attached to every event.
struct DeviceContext {
    let deviceId: String
    let iCloudId: String?
    let osVersion: String
    let deviceModel: String
    let appVersion: String?
    let appBuild: String?
    let locale: String
    let timezone: String
    let isDebug: Bool

    static let current: DeviceContext = .init()

    private init() {
        #if os(iOS) || os(tvOS)
        self.osVersion = UIDevice.current.systemVersion
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? DeviceContext.fallbackDeviceId()
        #else
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.deviceId = DeviceContext.fallbackDeviceId()
        #endif

        self.deviceModel = DeviceContext.hardwareModel()
        self.iCloudId = DeviceContext.iCloudTokenHash()

        let info = Bundle.main.infoDictionary
        self.appVersion = info?["CFBundleShortVersionString"] as? String
        self.appBuild = info?["CFBundleVersion"] as? String
        self.locale = Locale.current.identifier
        self.timezone = TimeZone.current.identifier

        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
    }

    private static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    private static func iCloudTokenHash() -> String? {
        guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        guard let data else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func fallbackDeviceId() -> String {
        let key = "ESupabaseAnalytics_deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
