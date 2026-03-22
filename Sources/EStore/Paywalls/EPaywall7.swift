import SwiftUI

/// Social proof paywall with review quotes and star ratings.
public struct EPaywall7: View {
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
                        // Stars
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .foregroundColor(t.accentColor)
                            }
                        }
                        .font(.title2)
                        .padding(.top, 20)

                        Text("Loved by Thousands")
                            .font(.title).bold()
                            .foregroundColor(t.textColor)

                        // Review cards
                        VStack(spacing: 12) {
                            ReviewCard(text: "\"Best app I've ever used. Worth every penny!\"", author: "Happy User", theme: t)
                            ReviewCard(text: "\"The premium features are incredible.\"", author: "Power User", theme: t)
                        }
                        .padding(.horizontal)

                        // Features
                        VStack(spacing: 12) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal)

                        Divider().padding(.horizontal)

                        // Products
                        VStack(spacing: 8) {
                            ForEach(data.premiumProducts) { product in
                                let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.first?.id)
                                EPaywallProductCard(product: product, isSelected: isSelected, theme: t) {
                                    selectedId = product.id
                                }
                            }
                        }
                        .padding(.horizontal)

                        EPaywallCTAButton("Join Premium", theme: t, isLoading: data.isLoading) {
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

private struct ReviewCard: View {
    let text: String
    let author: String
    let theme: EStoreTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.subheadline)
                .italic()
                .foregroundColor(theme.textColor)
            HStack {
                Text("— \(author)")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(theme.accentColor)
                    }
                }
            }
        }
        .padding()
        .background(theme.cardBackgroundColor)
        .cornerRadius(theme.cornerRadius)
    }
}
