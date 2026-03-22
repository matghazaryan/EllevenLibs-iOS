import SwiftUI

/// Consumable purchase paywall with a grid of coin/credit packs.
public struct EPaywall10: View {
    @StateObject private var data: EPaywallData

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        let consumables = data.consumables
        let allConsumables = consumables.isEmpty ? data.premiumProducts : consumables

        ZStack {
            t.backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Store")
                        .font(.title).bold()
                        .foregroundColor(t.textColor)
                    Spacer()
                    EPaywallCloseButton(theme: t) { data.onDismiss?() }
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 20) {
                        // Features
                        if !data.features.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                    EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Balance display (for consumables)
                        if !consumables.isEmpty {
                            let firstId = consumables.first?.id ?? ""
                            let balance = EStore.shared.consumableBalance(for: firstId)
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.title)
                                    .foregroundColor(t.accentColor)
                                Text("Balance: \(balance)")
                                    .font(.title2).bold()
                                    .foregroundColor(t.textColor)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(t.cardBackgroundColor)
                            .cornerRadius(t.cornerRadius)
                            .padding(.horizontal)
                        }

                        // Grid of products
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(allConsumables) { product in
                                let iconName: String = {
                                    if case .consumable(let amt) = product.type {
                                        if amt >= 500 { return "trophy.fill" }
                                        if amt >= 100 { return "star.circle.fill" }
                                        return "circle.fill"
                                    }
                                    return product.config.iconName ?? "bag.fill"
                                }()

                                VStack(spacing: 10) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 36))
                                        .foregroundColor(t.accentColor)
                                    Text(product.localizedTitle)
                                        .font(.headline)
                                        .foregroundColor(t.textColor)
                                    Text(product.localizedDescription)
                                        .font(.caption)
                                        .foregroundColor(t.secondaryTextColor)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)

                                    Button {
                                        Task { await data.purchase(product.id) }
                                    } label: {
                                        Text(product.displayPrice)
                                            .font(.subheadline).bold()
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(t.primaryColor)
                                            .cornerRadius(12)
                                    }
                                }
                                .padding()
                                .background(t.cardBackgroundColor)
                                .cornerRadius(t.cornerRadius)
                            }
                        }
                        .padding(.horizontal)

                        EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }
}
