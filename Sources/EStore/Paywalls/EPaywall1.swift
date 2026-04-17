import SwiftUI

/// Minimal paywall with a single highlighted product and feature list.
public struct EPaywall1: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            // Background: image if provided, otherwise solid color
            if let bgImage = t.backgroundImageName {
                Image(bgImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                t.backgroundColor.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Close
                HStack { Spacer(); EPaywallCloseButton(theme: t) { data.onDismiss?() } }
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48))
                                .foregroundColor(t.accentColor)
                            Text("Go Premium")
                                .font(t.font(size: 34, weight: .bold))
                                .foregroundColor(t.textColor)
                            Text("Unlock all features")
                                .font(t.font(size: 15))
                                .foregroundColor(t.secondaryTextColor)
                        }
                        .padding(.top, 20)

                        // Features
                        VStack(spacing: 12) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal)

                        // Products
                        VStack(spacing: 8) {
                            ForEach(data.premiumProducts) { product in
                                EPaywallProductCard(
                                    product: product,
                                    isSelected: selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.first?.id),
                                    theme: t
                                ) {
                                    selectedId = product.id
                                }
                            }
                        }
                        .padding(.horizontal)

                        // CTA
                        EPaywallCTAButton("Subscribe Now", theme: t, isLoading: data.isLoading) {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        }
                        .padding(.horizontal)

                        EPaywallRestoreButton(theme: t) { Task { await data.restore() } }

                        // Terms & Privacy
                        if t.hasLegalLinks {
                            HStack(spacing: 16) {
                                if let termsURL = t.termsURL {
                                    Link("Terms of Use", destination: termsURL)
                                        .font(t.font(size: 12))
                                        .foregroundColor(t.secondaryTextColor)
                                }
                                if let privacyURL = t.privacyURL {
                                    Link("Privacy Policy", destination: privacyURL)
                                        .font(t.font(size: 12))
                                        .foregroundColor(t.secondaryTextColor)
                                }
                            }
                            .padding(.top, 8)
                        }

                        Spacer().frame(height: 20)
                    }
                }
            }
        }
    }
}
