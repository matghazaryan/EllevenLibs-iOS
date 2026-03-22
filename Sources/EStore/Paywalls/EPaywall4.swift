import SwiftUI

/// Full-screen hero paywall with gradient background.
public struct EPaywall4: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            LinearGradient(colors: [t.primaryColor, t.primaryColor.opacity(0.6), t.backgroundColor],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack { Spacer(); EPaywallCloseButton(theme: EStoreTheme(secondaryTextColor: .white.opacity(0.8))) { data.onDismiss?() } }
                    .padding(.horizontal)

                Spacer()

                // Hero text
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundColor(.white)
                    Text("Unlock\nEverything")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Start your premium journey today")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Bottom card
                VStack(spacing: 16) {
                    // Features
                    VStack(spacing: 10) {
                        ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.body)
                                    .foregroundColor(t.primaryColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(.subheadline).bold()
                                        .foregroundColor(t.textColor)
                                    if let subtitle = feature.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundColor(t.secondaryTextColor)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    ForEach(data.premiumProducts) { product in
                        let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.first?.id)
                        HStack {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(t.primaryColor)
                            VStack(alignment: .leading) {
                                Text(product.localizedTitle).font(.subheadline).bold()
                                if let period = product.subscriptionPeriod {
                                    Text(period).font(.caption).foregroundColor(t.secondaryTextColor)
                                }
                            }
                            Spacer()
                            Text(product.displayPrice).font(.headline).foregroundColor(t.primaryColor)
                        }
                        .padding()
                        .background(isSelected ? t.primaryColor.opacity(0.1) : t.cardBackgroundColor)
                        .cornerRadius(12)
                        .onTapGesture { selectedId = product.id }
                    }

                    EPaywallCTAButton("Start Now", theme: t, isLoading: data.isLoading) {
                        let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                        Task { await data.purchase(id) }
                    }

                    EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                }
                .padding(20)
                .background(t.backgroundColor)
                .cornerRadius(24)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }
}
