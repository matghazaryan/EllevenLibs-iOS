#if canImport(GoogleMobileAds)
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

    private var rewardedAd: RewardedAd?
    private var isLoading = false
    private var retryAttempt = 0
    private var onReward: ((EAdReward) -> Void)?
    private var onDismiss: (() -> Void)?

    /// Give up after this many consecutive failures; a fresh `load()` from the
    /// host app (e.g. the next time its screen appears) starts the count over.
    private static let maxRetryAttempts = 4

    private override init() {
        super.init()
    }

    /// True when `show()` has an ad to present right now. Callers that gate a
    /// user action on an ad can use this to decide *before* asking.
    public var isReady: Bool { rewardedAd != nil }

    /// Preloads a rewarded ad.
    ///
    /// Safe to call repeatedly — a load already in flight, or an ad already
    /// waiting, makes this a no-op rather than a wasted request. A failed load
    /// retries on a backoff, because the single-shot version left `show()`
    /// with nothing to present for the rest of the session after one bad
    /// moment (and every host app creates those).
    public func load() {
        guard let adUnitId = EAds.shared.rewardedAdUnitId else { return }
        guard !isLoading, rewardedAd == nil else { return }
        isLoading = true
        RewardedAd.load(with: adUnitId, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false
            if let error = error {
                print("[EAds] Rewarded ad failed to load: \(error.localizedDescription)")
                self.scheduleRetry()
                return
            }
            self.retryAttempt = 0
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    private func scheduleRetry() {
        guard retryAttempt < Self.maxRetryAttempts else {
            print("[EAds] Rewarded ad giving up after \(retryAttempt) attempts")
            return
        }
        retryAttempt += 1
        let delay = min(pow(2.0, Double(retryAttempt)), 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.load()
        }
    }

    /// Shows the rewarded ad if one is loaded.
    /// - Parameters:
    ///   - onReward: Called when the user earns a reward.
    ///   - onDismiss: Called when the ad is dismissed.
    ///   - onUnavailable: Called instead of `onDismiss` when there was no ad to
    ///     present at all. Defaults to `nil`, in which case `onDismiss` is
    ///     called as before — so existing callers keep their behaviour, but a
    ///     caller that passes this can finally tell "no fill" apart from "user
    ///     closed it", which the merged callback made impossible to measure.
    @MainActor
    public func show(
        onReward: @escaping (EAdReward) -> Void,
        onDismiss: (() -> Void)? = nil,
        onUnavailable: (() -> Void)? = nil
    ) {
        guard let ad = rewardedAd, let presenter = Self.topViewController() else {
            print("[EAds] Rewarded ad not ready")
            // Drop any callbacks left over from a previous show, so a late
            // delegate call from an older ad cannot run this caller's code.
            self.onReward = nil
            self.onDismiss = nil
            load()
            (onUnavailable ?? onDismiss)?()
            return
        }
        self.onReward = onReward
        self.onDismiss = onDismiss
        // A presented ad is spent. Clearing it here — rather than waiting for
        // the dismiss delegate — is what stops a stale, already-consumed ad
        // being handed to `present` on the next tap, which fails silently and
        // looks to the user like the ad simply stopped appearing.
        rewardedAd = nil
        ad.present(from: presenter) { [weak self] in
            let reward = ad.adReward
            self?.onReward?(EAdReward(amount: reward.amount.doubleValue, type: reward.type))
        }
    }

    /// The view controller actually able to present right now. `connectedScenes.first`
    /// and `windows.first` are both arbitrary, and a root controller that is
    /// already showing a sheet or fullScreenCover cannot present anything —
    /// both cases made `present` fail and the ad never appear.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
              var top = window.rootViewController else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

extension EAdsRewarded: FullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDismiss?()
        onReward = nil
        onDismiss = nil
        load()
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[EAds] Rewarded ad failed to present: \(error.localizedDescription)")
        onDismiss?()
        onReward = nil
        onDismiss = nil
        load()
    }
}
#else
import Foundation

/// Stub for platforms where Google Mobile Ads is not available.
public final class EAdsRewarded: @unchecked Sendable {
    public static let shared = EAdsRewarded()
    private init() {}

    public var isReady: Bool { false }

    public func load() {}

    public func show(
        onReward: @escaping (EAdReward) -> Void,
        onDismiss: (() -> Void)? = nil,
        onUnavailable: (() -> Void)? = nil
    ) {
        print("[EAds] Rewarded ads are not available on this platform.")
        (onUnavailable ?? onDismiss)?()
    }
}
#endif

/// Reward data from a rewarded ad.
public struct EAdReward {
    public let amount: Double
    public let type: String
}
