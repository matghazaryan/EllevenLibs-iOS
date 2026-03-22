import SwiftUI

/// Comparison paywall with side-by-side product cards.
public struct EPaywall2: View {
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
                    VStack(spacing: 24) {
                        Text("Choose Your Plan")
                            .font(.title).bold()
                            .foregroundColor(t.textColor)
                            .padding(.top, 20)

                        // Features
                        VStack(spacing: 12) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal)

                        // Side by side cards
                        HStack(spacing: 12) {
                            ForEach(data.premiumProducts) { product in
                                let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.last?.id)
                                VStack(spacing: 8) {
                                    if product.id == data.premiumProducts.last?.id {
                                        Text("BEST VALUE")
                                            .font(.caption2).bold()
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(t.accentColor)
                                            .cornerRadius(8)
                                    } else {
                                        Text(" ").font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                    }

                                    VStack(spacing: 6) {
                                        Text(product.localizedTitle)
                                            .font(.headline)
                                            .foregroundColor(isSelected ? .white : t.textColor)
                                        if let period = product.subscriptionPeriod {
                                            Text(period)
                                                .font(.caption)
                                                .foregroundColor(isSelected ? .white.opacity(0.8) : t.secondaryTextColor)
                                        }
                                        Divider()
                                        Text(product.displayPrice)
                                            .font(.title2).bold()
                                            .foregroundColor(isSelected ? .white : t.primaryColor)
                                        Text(product.localizedDescription)
                                            .font(.caption)
                                            .foregroundColor(isSelected ? .white.opacity(0.7) : t.secondaryTextColor)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? t.primaryColor : t.cardBackgroundColor)
                                    .cornerRadius(t.cornerRadius)
                                }
                                .onTapGesture { selectedId = product.id }
                            }
                        }
                        .padding(.horizontal)

                        EPaywallCTAButton("Continue", theme: t, isLoading: data.isLoading) {
                            let id = selectedId ?? data.premiumProducts.last?.id ?? ""
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
