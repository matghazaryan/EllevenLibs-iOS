import SwiftUI

/// Savings-focused paywall comparing monthly vs yearly pricing.
public struct EPaywall6: View {
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
                        VStack(spacing: 8) {
                            Text("Save More with Annual")
                                .font(.title).bold()
                                .foregroundColor(t.textColor)
                            Text("Choose the plan that works for you")
                                .foregroundColor(t.secondaryTextColor)
                        }
                        .padding(.top, 24)

                        // Features
                        VStack(spacing: 12) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal)

                        ForEach(data.premiumProducts) { product in
                            let isSelected = selectedId == product.id || (selectedId == nil && product.id == data.premiumProducts.last?.id)
                            HStack(spacing: 16) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(isSelected ? t.primaryColor : t.secondaryTextColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(product.localizedTitle)
                                            .font(.headline)
                                            .foregroundColor(t.textColor)
                                        if product.id == data.premiumProducts.last?.id {
                                            Text("SAVE")
                                                .font(.caption2).bold()
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(t.accentColor)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(product.localizedDescription)
                                        .font(.caption)
                                        .foregroundColor(t.secondaryTextColor)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.title3).bold()
                                    .foregroundColor(t.primaryColor)
                            }
                            .padding()
                            .background(isSelected ? t.primaryColor.opacity(0.08) : t.cardBackgroundColor)
                            .cornerRadius(t.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: t.cornerRadius)
                                    .stroke(isSelected ? t.primaryColor : .clear, lineWidth: 2)
                            )
                            .onTapGesture { selectedId = product.id }
                        }
                        .padding(.horizontal)

                        EPaywallCTAButton("Subscribe", theme: t, isLoading: data.isLoading) {
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
