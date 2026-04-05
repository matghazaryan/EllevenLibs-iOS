#if canImport(GoogleMobileAds)
import SwiftUI
import GoogleMobileAds

/// A SwiftUI view that displays a Google AdMob banner ad.
///
/// Usage:
///     EAdsBanner()
///         .frame(height: 50)
public struct EAdsBanner: UIViewRepresentable {
    private let adSize: AdSize

    /// Creates a banner ad view.
    /// - Parameter adSize: The banner size. Defaults to adaptive banner.
    public init(adSize: AdSize = AdSizeBanner) {
        self.adSize = adSize
    }

    public func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = EAds.shared.bannerAdUnitId
        bannerView.delegate = context.coordinator
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootVC
        }
        bannerView.load(Request())
        return bannerView
    }

    public func updateUIView(_ uiView: BannerView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public class Coordinator: NSObject, BannerViewDelegate {
        public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[EAds] Banner failed to load: \(error.localizedDescription)")
        }
    }
}
#else
import SwiftUI

/// Placeholder for platforms where Google Mobile Ads is not available.
public struct EAdsBanner: View {
    public init() {}

    public var body: some View {
        EmptyView()
    }
}
#endif
