#if canImport(GoogleMobileAds)
import UIKit
import GoogleMobileAds

/// Manages open app ads that show when the app comes to the foreground.
///
/// Usage:
///     // Manual: call when app becomes active
///     EAdsOpenApp.shared.show()
///
///     // Automatic: attach to app lifecycle
///     EAdsOpenApp.shared.attachToAppLifecycle()
public final class EAdsOpenApp: NSObject, @unchecked Sendable {
    public static let shared = EAdsOpenApp()

    private var appOpenAd: AppOpenAd?
    private var isShowingAd = false
    private var loadTime: Date?
    private var isAttachedToLifecycle = false

    private override init() {
        super.init()
    }

    /// Preloads an open app ad.
    public func load() {
        guard let adUnitId = EAds.shared.openAppAdUnitId else { return }
        guard appOpenAd == nil else { return } // Already loaded
        AppOpenAd.load(withAdUnitID: adUnitId, request: Request()) { [weak self] ad, error in
            if let error = error {
                print("[EAds] Open app ad failed to load: \(error.localizedDescription)")
                return
            }
            self?.appOpenAd = ad
            self?.appOpenAd?.fullScreenContentDelegate = self
            self?.loadTime = Date()
        }
    }

    /// Attaches to the app lifecycle to automatically show open app ads
    /// when the app comes to the foreground.
    @MainActor
    public func attachToAppLifecycle() {
        guard !isAttachedToLifecycle else { return }
        isAttachedToLifecycle = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        Task { @MainActor in
            show()
        }
    }

    /// Shows the open app ad if one is loaded and not expired (4 hours).
    @MainActor
    public func show() {
        guard !isShowingAd else { return }
        guard let ad = appOpenAd, !isAdExpired() else {
            appOpenAd = nil
            load()
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        isShowingAd = true
        ad.present(fromRootViewController: rootVC)
    }

    private func isAdExpired() -> Bool {
        guard let loadTime = loadTime else { return true }
        return Date().timeIntervalSince(loadTime) > 4 * 3600 // 4 hours
    }
}

extension EAdsOpenApp: FullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isShowingAd = false
        appOpenAd = nil
        load()
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[EAds] Open app ad failed to present: \(error.localizedDescription)")
        isShowingAd = false
        appOpenAd = nil
        load()
    }
}
#else
import Foundation

/// Stub for platforms where Google Mobile Ads is not available.
public final class EAdsOpenApp: @unchecked Sendable {
    public static let shared = EAdsOpenApp()
    private init() {}

    public func load() {}
    public func attachToAppLifecycle() {}

    public func show() {
        print("[EAds] Open app ads are not available on this platform.")
    }
}
#endif
