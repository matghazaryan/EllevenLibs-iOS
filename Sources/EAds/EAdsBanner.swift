import SwiftUI
import GoogleMobileAds

/// A SwiftUI view that displays a Google AdMob banner ad.
///
/// Usage:
///     EAdsBanner()
///         .frame(height: 50)
public struct EAdsBanner: UIViewRepresentable {
    private let adSize: GADAdSize

    /// Creates a banner ad view.
    /// - Parameter adSize: The banner size. Defaults to adaptive banner.
    public init(adSize: GADAdSize = GADAdSizeBanner) {
        self.adSize = adSize
    }

    public func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: adSize)
        bannerView.adUnitID = EAds.shared.bannerAdUnitId
        bannerView.delegate = context.coordinator
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootVC
        }
        bannerView.load(GADRequest())
        return bannerView
    }

    public func updateUIView(_ uiView: GADBannerView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public class Coordinator: NSObject, GADBannerViewDelegate {
        public func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[EAds] Banner failed to load: \(error.localizedDescription)")
        }
    }
}
