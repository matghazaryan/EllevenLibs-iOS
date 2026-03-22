import SwiftUI

/// Compact bottom-sheet style paywall.
public struct EPaywall9: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        VStack(spacing: 20) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(t.secondaryTextColor.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            HStack {
                Text("Go Premium")
                    .font(.title2).bold()
                    .foregroundColor(t.textColor)
                Spacer()
                EPaywallCloseButton(theme: t) { data.onDismiss?() }
            }
            .padding(.horizontal)

            // Features
            VStack(spacing: 10) {
                ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                    EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                }
            }
            .padding(.horizontal)

            // Horizontal products
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(data.premiumProducts) { product in
                        let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.first?.id)
                        VStack(spacing: 8) {
                            Text(product.localizedTitle)
                                .font(.subheadline).bold()
                            Text(product.displayPrice)
                                .font(.title3).bold()
                            if let period = product.subscriptionPeriod {
                                Text(period).font(.caption)
                            }
                        }
                        .foregroundColor(isSelected ? .white : t.textColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(isSelected ? t.primaryColor : t.cardBackgroundColor)
                        .cornerRadius(t.cornerRadius)
                        .onTapGesture { selectedId = product.id }
                    }
                }
                .padding(.horizontal)
            }

            EPaywallCTAButton("Subscribe", theme: t, isLoading: data.isLoading) {
                let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                Task { await data.purchase(id) }
            }
            .padding(.horizontal)

            EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                .padding(.bottom, 20)
        }
        .background(t.backgroundColor)
        .cornerRadius(24)
    }
}
