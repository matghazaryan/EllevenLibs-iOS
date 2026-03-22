import UIKit
import GoogleMobileAds

/// Manages rewarded ads with automatic preloading.
///
/// Usage:
///     EAdsRewarded.shared.show { reward in
///         print("User earned: \(reward.amount) \(reward.type)")
///     }
public final class EAdsRewarded: NSObject, @unchecked Sendable {
    public static let shared = EAdsRewarded()

    private var rewardedAd: GADRewardedAd?
    private var onReward: ((EAdReward) -> Void)?
    private var onDismiss: (() -> Void)?

    private override init() {
        super.init()
    }

    /// Preloads a rewarded ad.
    public func load() {
        guard let adUnitId = EAds.shared.rewardedAdUnitId else { return }
        GADRewardedAd.load(withAdUnitID: adUnitId, request: GADRequest()) { [weak self] ad, error in
            if let error = error {
                print("[EAds] Rewarded ad failed to load: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    /// Shows the rewarded ad if one is loaded.
    /// - Parameters:
    ///   - onReward: Called when the user earns a reward.
    ///   - onDismiss: Called when the ad is dismissed.
    @MainActor
    public func show(onReward: @escaping (EAdReward) -> Void, onDismiss: (() -> Void)? = nil) {
        self.onReward = onReward
        self.onDismiss = onDismiss
        guard let ad = rewardedAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("[EAds] Rewarded ad not ready")
            onDismiss?()
            return
        }
        ad.present(fromRootViewController: rootVC) { [weak self] in
            let reward = ad.adReward
            self?.onReward?(EAdReward(amount: reward.amount.doubleValue, type: reward.type))
        }
    }
}

extension EAdsRewarded: GADFullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        onDismiss?()
        onReward = nil
        onDismiss = nil
        load()
    }

    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[EAds] Rewarded ad failed to present: \(error.localizedDescription)")
        onDismiss?()
        onReward = nil
        onDismiss = nil
        load()
    }
}

/// Reward data from a rewarded ad.
public struct EAdReward {
    public let amount: Double
    public let type: String
}
