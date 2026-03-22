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

    private var appOpenAd: GADAppOpenAd?
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
        GADAppOpenAd.load(withAdUnitID: adUnitId, request: GADRequest()) { [weak self] ad, error in
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

extension EAdsOpenApp: GADFullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        isShowingAd = false
        appOpenAd = nil
        load()
    }

    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[EAds] Open app ad failed to present: \(error.localizedDescription)")
        isShowingAd = false
        appOpenAd = nil
        load()
    }
}
