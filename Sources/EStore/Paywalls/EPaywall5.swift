import SwiftUI

/// Horizontal carousel paywall with swipeable product cards.
public struct EPaywall5: View {
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
                HStack {
                    Text("Premium").font(.title2).bold().foregroundColor(t.textColor)
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

                Spacer()

                TabView(selection: Binding(
                    get: { selectedId ?? data.premiumProducts.first?.id ?? "" },
                    set: { selectedId = $0 }
                )) {
                    ForEach(data.premiumProducts) { product in
                        VStack(spacing: 16) {
                            Image(systemName: product.config.iconName ?? "star.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(t.accentColor)
                            Text(product.localizedTitle)
                                .font(.title).bold()
                                .foregroundColor(t.textColor)
                            Text(product.localizedDescription)
                                .font(.body)
                                .foregroundColor(t.secondaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Text(product.displayPrice)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(t.primaryColor)
                            if let period = product.subscriptionPeriod {
                                Text(period)
                                    .font(.subheadline)
                                    .foregroundColor(t.secondaryTextColor)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(t.cardBackgroundColor)
                        .cornerRadius(t.cornerRadius)
                        .padding(.horizontal, 24)
                        .tag(product.id)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                #endif
                .frame(height: 350)

                Spacer()

                VStack(spacing: 12) {
                    EPaywallCTAButton("Get Started", theme: t, isLoading: data.isLoading) {
                        let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                        Task { await data.purchase(id) }
                    }
                    EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}
