import Foundation
import EStore
import EAds

/// Central manager for the play-limit gate system.
/// Tracks how many games a user has played and triggers a gate UI when the limit is reached.
///
/// Usage:
///     // Configure (call once at app launch)
///     EGate.shared.configure(EGateConfig(maxPlays: 5))
///
///     // After each game
///     EGate.shared.recordPlay()
///     if EGate.shared.shouldShowGate {
///         // show EGateView
///     }
///
///     // Or use the SwiftUI modifier
///     .eGate()
@MainActor
public final class EGate: ObservableObject {
    public static let shared = EGate()

    @Published public private(set) var currentCount: Int = 0
    @Published public private(set) var shouldShowGate: Bool = false

    public private(set) var config: EGateConfig = EGateConfig()

    private init() {}

    /// Configure EGate with your settings. Call once at app launch.
    public func configure(_ config: EGateConfig) {
        self.config = config
        self.currentCount = UserDefaults.standard.integer(forKey: config.storageKey)
        updateGateState()
    }

    /// Record a play. Call this after each game round ends.
    /// Returns true if the gate should now be shown.
    @discardableResult
    public func recordPlay() -> Bool {
        currentCount += 1
        UserDefaults.standard.set(currentCount, forKey: config.storageKey)
        updateGateState()
        return shouldShowGate
    }

    /// Reset the play counter to zero.
    public func reset() {
        currentCount = 0
        UserDefaults.standard.set(0, forKey: config.storageKey)
        updateGateState()
    }

    /// Called when user watches an ad. Resets count if configured.
    public func onAdWatched() {
        if config.resetAfterAd {
            reset()
        }
    }

    /// Dismiss the gate without taking action.
    public func dismiss() {
        shouldShowGate = false
    }

    /// Called when user becomes premium. Gate will no longer show.
    public func onPremiumPurchased() {
        shouldShowGate = false
    }

    /// Show a rewarded ad using EAds.
    public func showRewardedAd() {
        EAdsRewarded.shared.show(
            onReward: { [weak self] _ in
                self?.onAdWatched()
            },
            onDismiss: nil
        )
    }

    private func updateGateState() {
        // Never show gate if user is premium
        if EStore.shared.isPremium {
            shouldShowGate = false
            return
        }
        shouldShowGate = currentCount >= config.maxPlays
    }
}
