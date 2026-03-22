import SwiftUI

/// Netflix/Spotify-style paywall with animated gradient background, shimmer text, and pulsating CTA.
public struct EPaywall11: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?
    @State private var animateGradient = false
    @State private var isPulsing = false
    @State private var appeared = false

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [t.primaryColor, t.accentColor, t.primaryColor.opacity(0.8)],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)

            VStack(spacing: 0) {
                // Close button with blur circle
                HStack {
                    Spacer()
                    EPaywall11CloseButton { data.onDismiss?() }
                }
                .padding(.horizontal)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header with shimmer
                        VStack(spacing: 12) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

                            EPaywall11ShimmerText(text: "Unlock Premium")
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.easeOut(duration: 0.6).delay(0.35), value: appeared)

                            Text("Get unlimited access to all features")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)
                        }
                        .padding(.top, 20)

                        // Features on glass card
                        VStack(spacing: 14) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywall11FeatureItem(icon: feature.icon, text: feature.title)
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)

                        // Product cards on glass
                        VStack(spacing: 10) {
                            ForEach(data.premiumProducts) { product in
                                let isSelected = selectedId == product.id ||
                                    (selectedId == nil && product.id == data.premiumProducts.first?.id)
                                EPaywall11ProductCard(product: product, isSelected: isSelected) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedId = product.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.easeOut(duration: 0.6).delay(0.75), value: appeared)

                        // Pulsating CTA
                        Button {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        } label: {
                            HStack {
                                if data.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Continue")
                                        .fontWeight(.bold)
                                        .font(.title3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.white)
                            .foregroundColor(t.primaryColor)
                            .cornerRadius(16)
                        }
                        .disabled(data.isLoading)
                        .scaleEffect(isPulsing ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.easeOut(duration: 0.6).delay(0.9), value: appeared)

                        // Restore
                        Button("Restore Purchases") {
                            Task { await data.restore() }
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(1.0), value: appeared)
                    }
                }
            }
        }
        .onAppear {
            animateGradient = true
            isPulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }
}

// MARK: - Private Components

private struct EPaywall11CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

private struct EPaywall11ShimmerText: View {
    let text: String
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 80)
                    .offset(x: shimmerOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                            shimmerOffset = geo.size.width + 80
                        }
                    }
                }
                .mask(
                    Text(text)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                )
            )
    }
}

private struct EPaywall11FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

private struct EPaywall11ProductCard: View {
    let product: EStoreProduct
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.localizedTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let period = product.subscriptionPeriod {
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
