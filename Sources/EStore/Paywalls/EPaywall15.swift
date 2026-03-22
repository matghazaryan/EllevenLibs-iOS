import SwiftUI

/// 3D card / parallax-style interactive paywall with drag gestures, shine effects, and countdown timer.
public struct EPaywall15: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?
    @State private var dragOffset: CGSize = .zero
    @State private var appeared = false
    @State private var shineOffset: CGFloat = -200
    @State private var timeRemaining: Int = 23 * 3600 + 59 * 60 + 59

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            // Background layers for parallax depth
            EPaywall15ParallaxBackground(
                primaryColor: t.primaryColor,
                accentColor: t.accentColor,
                dragOffset: dragOffset
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
                    VStack(spacing: 24) {
                        // Timer banner
                        EPaywall15CountdownBanner(timeRemaining: timeRemaining, theme: t)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -20)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                        // Header with parallax offset
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [t.primaryColor, t.accentColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .offset(
                                    x: dragOffset.width / 8,
                                    y: dragOffset.height / 8
                                )

                            Text("Premium Access")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(t.textColor)
                                .offset(
                                    x: dragOffset.width / 15,
                                    y: dragOffset.height / 15
                                )

                            Text("Unlock your full potential")
                                .font(.subheadline)
                                .foregroundColor(t.secondaryTextColor)
                        }
                        .padding(.top, 8)
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: appeared)

                        // Features
                        VStack(spacing: 12) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { _, feature in
                                EPaywallFeatureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle, theme: t)
                            }
                        }
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.35), value: appeared)

                        // 3D Product cards
                        VStack(spacing: 12) {
                            ForEach(Array(data.premiumProducts.enumerated()), id: \.element.id) { index, product in
                                let isSelected = selectedId == product.id ||
                                    (selectedId == nil && product.id == data.premiumProducts.first?.id)

                                EPaywall15Card3D(
                                    product: product,
                                    isSelected: isSelected,
                                    theme: t,
                                    dragOffset: dragOffset
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedId = product.id
                                    }
                                }
                                .scaleEffect(appeared ? 1 : 0.7)
                                .opacity(appeared ? 1 : 0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.6)
                                        .delay(0.4 + Double(index) * 0.12),
                                    value: appeared
                                )
                            }
                        }
                        .padding(.horizontal)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = CGSize(
                                        width: value.translation.width * 0.4,
                                        height: value.translation.height * 0.4
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        dragOffset = .zero
                                    }
                                }
                        )

                        // CTA with shine sweep
                        EPaywall15ShineButton(
                            title: "Start Now",
                            theme: t,
                            isLoading: data.isLoading,
                            shineOffset: shineOffset
                        ) {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        }
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.easeOut(duration: 0.6).delay(0.8), value: appeared)

                        EPaywallRestoreButton(theme: t) { Task { await data.restore() } }
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            appeared = true
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shineOffset = 400
            }
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
}

// MARK: - Parallax Background

private struct EPaywall15ParallaxBackground: View {
    let primaryColor: Color
    let accentColor: Color
    let dragOffset: CGSize

    var body: some View {
        ZStack {
            Color(white: 0.97)

            // Deep layer - moves least
            Circle()
                .fill(primaryColor.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(
                    x: -80 + dragOffset.width / 25,
                    y: -100 + dragOffset.height / 25
                )

            // Mid layer
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(
                    x: 100 + dragOffset.width / 15,
                    y: 200 + dragOffset.height / 15
                )

            // Near layer - moves most
            Circle()
                .fill(primaryColor.opacity(0.06))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(
                    x: 60 + dragOffset.width / 8,
                    y: -50 + dragOffset.height / 8
                )
        }
    }
}

// MARK: - Countdown Banner

private struct EPaywall15CountdownBanner: View {
    let timeRemaining: Int
    let theme: EStoreTheme

    private var hours: Int { timeRemaining / 3600 }
    private var minutes: Int { (timeRemaining % 3600) / 60 }
    private var seconds: Int { timeRemaining % 60 }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundColor(theme.accentColor)

            Text("Offer expires in")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(theme.textColor)

            HStack(spacing: 2) {
                EPaywall15TimerDigit(value: hours)
                Text(":").font(.system(.caption, design: .monospaced, weight: .bold)).foregroundColor(theme.textColor)
                EPaywall15TimerDigit(value: minutes)
                Text(":").font(.system(.caption, design: .monospaced, weight: .bold)).foregroundColor(theme.textColor)
                EPaywall15TimerDigit(value: seconds)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(theme.accentColor.opacity(0.12))
        )
    }
}

private struct EPaywall15TimerDigit: View {
    let value: Int

    var body: some View {
        Text(String(format: "%02d", value))
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .foregroundColor(.primary)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3), value: value)
    }
}

// MARK: - 3D Product Card

private struct EPaywall15Card3D: View {
    let product: EStoreProduct
    let isSelected: Bool
    let theme: EStoreTheme
    let dragOffset: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? theme.primaryColor : theme.secondaryTextColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primaryColor)
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
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
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? theme.primaryColor.opacity(0.2) : .black.opacity(0.05),
                radius: isSelected ? 12 : 4,
                y: 2
            )
        }
        .rotation3DEffect(
            .degrees(Double(dragOffset.width / 20)),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(-dragOffset.height / 20)),
            axis: (x: 1, y: 0, z: 0)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Shine Button

private struct EPaywall15ShineButton: View {
    let title: String
    let theme: EStoreTheme
    let isLoading: Bool
    let shineOffset: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.bold)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(theme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.25), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80)
                    .offset(x: shineOffset)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
        }
        .disabled(isLoading)
    }
}
