import SwiftUI

/// Gradient paywall with stacked product chips.
public struct EPaywall8: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            LinearGradient(colors: [t.primaryColor.opacity(0.15), t.accentColor.opacity(0.1), t.backgroundColor],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack { Spacer(); EPaywallCloseButton(theme: t) { data.onDismiss?() } }
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 44))
                                .foregroundColor(t.primaryColor)
                            Text("Upgrade Today")
                                .font(.title).bold()
                                .foregroundColor(t.textColor)
                        }
                        .padding(.top, 24)

                        // Features
                        VStack(spacing: 12) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal)

                        VStack(spacing: 10) {
                            ForEach(data.premiumProducts) { product in
                                let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.first?.id)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.localizedTitle).font(.headline)
                                        Text(product.localizedDescription).font(.caption)
                                            .foregroundColor(isSelected ? .white.opacity(0.8) : t.secondaryTextColor)
                                    }
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }
                                .foregroundColor(isSelected ? .white : t.textColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(isSelected ? t.primaryColor : t.cardBackgroundColor)
                                .cornerRadius(40)
                                .onTapGesture { selectedId = product.id }
                            }
                        }
                        .padding(.horizontal)

                        EPaywallCTAButton("Continue", theme: t, isLoading: data.isLoading) {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        }
                        .padding(.horizontal)

                        EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                            .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}
