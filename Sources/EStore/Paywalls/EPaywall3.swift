import SwiftUI

/// Feature-focused paywall with checkmark list and product selection at bottom.
public struct EPaywall3: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            t.backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Spacer(); EPaywallCloseButton(theme: t) { data.onDismiss?() } }
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(t.accentColor)
                            .padding(.top, 20)

                        Text("Premium Features")
                            .font(.title).bold()
                            .foregroundColor(t.textColor)

                        VStack(spacing: 14) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal, 24)

                        Divider().padding(.horizontal)

                        // Horizontal product selection
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(data.premiumProducts) { product in
                                    let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.first?.id)
                                    VStack(spacing: 4) {
                                        Text(product.localizedTitle).font(.subheadline).bold()
                                            .foregroundColor(isSelected ? .white : t.textColor)
                                        Text(product.displayPrice).font(.headline)
                                            .foregroundColor(isSelected ? .white : t.primaryColor)
                                        if let period = product.subscriptionPeriod {
                                            Text(period).font(.caption)
                                                .foregroundColor(isSelected ? .white.opacity(0.8) : t.secondaryTextColor)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .background(isSelected ? t.primaryColor : t.cardBackgroundColor)
                                    .cornerRadius(t.cornerRadius)
                                    .onTapGesture { selectedId = product.id }
                                }
                            }
                            .padding(.horizontal)
                        }

                        EPaywallCTAButton("Get Premium", theme: t, isLoading: data.isLoading) {
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
