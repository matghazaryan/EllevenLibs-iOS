import SwiftUI

/// Floating particles / confetti-style paywall with dark background and animated elements.
public struct EPaywall12: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?
    @State private var appeared = false
    @State private var bounceIn = false

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            // Floating particles
            EPaywall12ParticleField(color: t.primaryColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    EPaywallCloseButton(theme: EStoreTheme(
                        secondaryTextColor: .white.opacity(0.6)
                    )) { data.onDismiss?() }
                }
                .padding(.horizontal)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            EPaywall12AnimatedCheckmarkIcon(color: t.primaryColor)
                                .frame(width: 64, height: 64)

                            Text("Upgrade Your Experience")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Choose the plan that works best for you")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.easeOut(duration: 0.7).delay(0.2), value: appeared)

                        // Features
                        VStack(spacing: 14) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { index, feature in
                                EPaywall12FeatureRow(icon: feature.icon, text: feature.title, color: t.primaryColor, delay: 0.4 + Double(index) * 0.1, appeared: appeared)
                            }
                        }
                        .padding(.horizontal)

                        // Product cards with glow
                        VStack(spacing: 12) {
                            ForEach(Array(data.premiumProducts.enumerated()), id: \.element.id) { index, product in
                                let isSelected = selectedId == product.id ||
                                    (selectedId == nil && product.id == data.premiumProducts.first?.id)
                                let isRecommended = index == (data.premiumProducts.count > 1 ? 1 : 0)

                                EPaywall12ProductCard(
                                    product: product,
                                    isSelected: isSelected,
                                    isRecommended: isRecommended,
                                    theme: t
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedId = product.id
                                    }
                                }
                                .scaleEffect(bounceIn ? 1.0 : 0.8)
                                .opacity(bounceIn ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3 + Double(index) * 0.1), value: bounceIn)
                            }
                        }
                        .padding(.horizontal)

                        // Bouncy CTA
                        Button {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        } label: {
                            HStack {
                                if data.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Get Started")
                                        .fontWeight(.bold)
                                        .font(.title3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(t.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(data.isLoading)
                        .padding(.horizontal)
                        .scaleEffect(bounceIn ? 1.0 : 0.5)
                        .opacity(bounceIn ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.7), value: bounceIn)

                        Button("Restore Purchases") {
                            Task { await data.restore() }
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            appeared = true
            bounceIn = true
        }
    }
}

// MARK: - Particle Field

private struct EPaywall12ParticleField: View {
    let color: Color
    @State private var animate = false

    private struct Particle: Identifiable {
        let id: Int
        let x: CGFloat
        let startY: CGFloat
        let size: CGFloat
        let opacity: Double
        let speed: Double
    }

    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                Circle()
                    .fill(color.opacity(p.opacity))
                    .frame(width: p.size, height: p.size)
                    .position(
                        x: p.x,
                        y: animate ? -20 : p.startY
                    )
                    .animation(
                        .linear(duration: p.speed)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
            }
            .onAppear {
                particles = (0..<25).map { i in
                    Particle(
                        id: i,
                        x: CGFloat.random(in: 0...geo.size.width),
                        startY: CGFloat.random(in: geo.size.height * 0.3...geo.size.height + 50),
                        size: CGFloat.random(in: 2...6),
                        opacity: Double.random(in: 0.15...0.5),
                        speed: Double.random(in: 4...10)
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animate = true
                }
            }
        }
    }
}

// MARK: - Animated Checkmark Icon

private struct EPaywall12AnimatedCheckmarkIcon: View {
    let color: Color
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))

            Circle()
                .stroke(color, lineWidth: 2)
                .scaleEffect(drawProgress)
                .opacity(drawProgress)

            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
                .scaleEffect(drawProgress)
                .opacity(drawProgress)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3)) {
                drawProgress = 1
            }
        }
    }
}

// MARK: - Feature Row

private struct EPaywall12FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    let delay: Double
    let appeared: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }
}

// MARK: - Product Card with Glow

private struct EPaywall12ProductCard: View {
    let product: EStoreProduct
    let isSelected: Bool
    let isRecommended: Bool
    let theme: EStoreTheme
    let action: () -> Void

    @State private var glowPulse = false
    @State private var borderRotation: Double = 0

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if isRecommended {
                    Text("MOST POPULAR")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(theme.primaryColor)
                        .cornerRadius(8, corners: [.topLeft, .topRight])
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.localizedTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        if let period = product.subscriptionPeriod {
                            Text(period)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Text(product.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryColor)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.06))
            )
            .overlay(
                Group {
                    if isRecommended {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                AngularGradient(
                                    colors: [theme.primaryColor, theme.accentColor, theme.primaryColor.opacity(0.3), theme.primaryColor],
                                    center: .center,
                                    angle: .degrees(borderRotation)
                                ),
                                lineWidth: 2
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? theme.primaryColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
            )
            .shadow(color: isSelected ? theme.primaryColor.opacity(glowPulse ? 0.4 : 0.15) : .clear, radius: 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            if isRecommended {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    borderRotation = 360
                }
            }
        }
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(EPaywall12RoundedCorner(radius: radius, corners: corners))
    }
}

private struct EPaywall12RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
