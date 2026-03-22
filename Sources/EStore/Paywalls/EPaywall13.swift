import SwiftUI

/// Glassmorphism / iOS-style paywall with frosted glass cards and floating blobs.
public struct EPaywall13: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?
    @State private var moveBlobs = false
    @State private var appeared = false
    @State private var crownRotation: Double = 0

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            // Light background
            t.backgroundColor.ignoresSafeArea()

            // Floating background blobs
            EPaywall13FloatingBlobs(
                primaryColor: t.primaryColor,
                accentColor: t.accentColor,
                moveBlobs: moveBlobs
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    EPaywallCloseButton(theme: t) { data.onDismiss?() }
                }
                .padding(.horizontal)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Crown icon with rotation
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(t.primaryColor.opacity(0.1))
                                    .frame(width: 88, height: 88)

                                Image(systemName: "crown.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [t.primaryColor, t.accentColor],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .rotationEffect(.degrees(crownRotation))
                            }
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: appeared)

                            Text("Go Premium")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(t.textColor)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.6).delay(0.35), value: appeared)

                            // Animated underline text
                            EPaywall13AnimatedUnderlineText(
                                text: "Try Free for 7 Days",
                                color: t.primaryColor,
                                appeared: appeared
                            )
                        }
                        .padding(.top, 16)

                        // Features on glass card
                        VStack(spacing: 16) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywall13FeatureItem(icon: feature.icon, title: feature.title, subtitle: feature.subtitle ?? "", theme: t)
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)

                        // Glass product cards
                        VStack(spacing: 10) {
                            ForEach(data.premiumProducts) { product in
                                let isSelected = selectedId == product.id ||
                                    (selectedId == nil && product.id == data.premiumProducts.first?.id)

                                EPaywall13GlassProductCard(
                                    product: product,
                                    isSelected: isSelected,
                                    theme: t
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedId = product.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.65), value: appeared)

                        // CTA
                        EPaywallCTAButton("Start Free Trial", theme: t, isLoading: data.isLoading) {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        }
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.8), value: appeared)

                        EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            moveBlobs = true
            appeared = true
            withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                crownRotation = -10
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1.8)) {
                crownRotation = 10
            }
        }
    }
}

// MARK: - Floating Blobs

private struct EPaywall13FloatingBlobs: View {
    let primaryColor: Color
    let accentColor: Color
    let moveBlobs: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(primaryColor.opacity(0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 65)
                .offset(
                    x: moveBlobs ? 60 : -60,
                    y: moveBlobs ? -40 : 40
                )
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: moveBlobs)

            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 180, height: 180)
                .blur(radius: 55)
                .offset(
                    x: moveBlobs ? -50 : 70,
                    y: moveBlobs ? 60 : -20
                )
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: moveBlobs)

            Circle()
                .fill(primaryColor.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 50)
                .offset(
                    x: moveBlobs ? 30 : -40,
                    y: moveBlobs ? 100 : 200
                )
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: moveBlobs)
        }
    }
}

// MARK: - Animated Underline Text

private struct EPaywall13AnimatedUnderlineText: View {
    let text: String
    let color: Color
    let appeared: Bool
    @State private var underlineWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(color)

            Rectangle()
                .fill(color)
                .frame(height: 2)
                .frame(width: underlineWidth)
                .animation(.easeOut(duration: 0.8).delay(0.6), value: underlineWidth)
        }
        .onChange(of: appeared) { newVal in
            if newVal {
                underlineWidth = 180
            }
        }
        .onAppear {
            if appeared {
                underlineWidth = 180
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.45), value: appeared)
    }
}

// MARK: - Feature Item

private struct EPaywall13FeatureItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let theme: EStoreTheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.primaryColor, theme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(theme.textColor)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(theme.secondaryTextColor)
            }
            Spacer()
        }
    }
}

// MARK: - Glass Product Card

private struct EPaywall13GlassProductCard: View {
    let product: EStoreProduct
    let isSelected: Bool
    let theme: EStoreTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(isSelected ? theme.primaryColor : theme.secondaryTextColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.localizedTitle)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(theme.textColor)
                    if let period = product.subscriptionPeriod {
                        Text(period)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(theme.primaryColor)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}
