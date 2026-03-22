import UIKit
import GoogleMobileAds

/// Manages interstitial ads with automatic preloading.
///
/// Usage:
///     EAdsInterstitial.shared.show()
public final class EAdsInterstitial: NSObject, @unchecked Sendable {
    public static let shared = EAdsInterstitial()

    private var interstitialAd: GADInterstitialAd?
    private var onDismiss: (() -> Void)?

    private override init() {
        super.init()
    }

    /// Preloads an interstitial ad.
    public func load() {
        guard let adUnitId = EAds.shared.interstitialAdUnitId else { return }
        GADInterstitialAd.load(withAdUnitID: adUnitId, request: GADRequest()) { [weak self] ad, error in
            if let error = error {
                print("[EAds] Interstitial failed to load: \(error.localizedDescription)")
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
        }
    }

    /// Shows the interstitial ad if one is loaded.
    /// - Parameter onDismiss: Called when the ad is dismissed. A new ad is preloaded automatically.
    @MainActor
    public func show(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        guard let ad = interstitialAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("[EAds] Interstitial not ready")
            onDismiss?()
            return
        }
        ad.present(fromRootViewController: rootVC)
    }
}

extension EAdsInterstitial: GADFullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        onDismiss?()
        onDismiss = nil
        load() // Preload next
    }

    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[EAds] Interstitial failed to present: \(error.localizedDescription)")
        onDismiss?()
        onDismiss = nil
        load()
    }
}
