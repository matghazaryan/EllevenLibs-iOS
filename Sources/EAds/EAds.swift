import Foundation
import GoogleMobileAds

/// Ad unit ID pair for debug and production environments.
public struct EAdUnitId {
    public let debug: String
    public let production: String

    public init(debug: String, production: String) {
        self.debug = debug
        self.production = production
    }
}

/// Central manager for Google AdMob integration.
/// You MUST provide your own ad unit IDs (both debug and production).
/// The library automatically selects the correct one based on build configuration.
///
/// Usage:
///     EAds.configure(
///         banner: EAdUnitId(
///             debug: "ca-app-pub-3940256099942544/2934735716",
///             production: "ca-app-pub-YOUR_ID/YOUR_BANNER"
///         ),
///         interstitial: EAdUnitId(
///             debug: "ca-app-pub-3940256099942544/4411468910",
///             production: "ca-app-pub-YOUR_ID/YOUR_INTERSTITIAL"
///         )
///     )
public final class EAds {
    public static let shared = EAds()

    private(set) var bannerAdUnitId: String?
    private(set) var interstitialAdUnitId: String?
    private(set) var rewardedAdUnitId: String?
    private(set) var openAppAdUnitId: String?
    private(set) var isInitialized = false

    private init() {}

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Configure EAds with your ad unit IDs. At least one ad type must be provided.
    /// Both debug and production IDs are required for each ad type you use.
    ///
    /// - Parameters:
    ///   - banner: Banner ad unit IDs (debug + production)
    ///   - interstitial: Interstitial ad unit IDs (debug + production)
    ///   - rewarded: Rewarded ad unit IDs (debug + production)
    ///   - openApp: Open app ad unit IDs (debug + production)
    public static func configure(
        banner: EAdUnitId? = nil,
        interstitial: EAdUnitId? = nil,
        rewarded: EAdUnitId? = nil,
        openApp: EAdUnitId? = nil
    ) {
        precondition(
            banner != nil || interstitial != nil || rewarded != nil || openApp != nil,
            "[EAds] ERROR: You must provide at least one ad unit ID. Pass EAdUnitId(debug:production:) for each ad type you want to use."
        )

        let instance = shared
        instance.bannerAdUnitId = banner.map { isDebug ? $0.debug : $0.production }
        instance.interstitialAdUnitId = interstitial.map { isDebug ? $0.debug : $0.production }
        instance.rewardedAdUnitId = rewarded.map { isDebug ? $0.debug : $0.production }
        instance.openAppAdUnitId = openApp.map { isDebug ? $0.debug : $0.production }

        GADMobileAds.sharedInstance().start { _ in
            instance.isInitialized = true
            if instance.interstitialAdUnitId != nil {
                EAdsInterstitial.shared.load()
            }
            if instance.rewardedAdUnitId != nil {
                EAdsRewarded.shared.load()
            }
            if instance.openAppAdUnitId != nil {
                EAdsOpenApp.shared.load()
            }
        }
    }
}
