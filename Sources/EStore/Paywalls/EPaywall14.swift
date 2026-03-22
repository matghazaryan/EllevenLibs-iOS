import SwiftUI

/// Dark premium / luxury-style paywall with gold accents, animated borders, and typewriter text.
public struct EPaywall14: View {
    @StateObject private var data: EPaywallData
    @State private var selectedId: String?
    @State private var displayedText = ""
    @State private var appeared = false
    @State private var diamondScale: CGFloat = 0.3
    @State private var diamondRotation: Double = -30
    @State private var sparkleOpacities: [Bool] = Array(repeating: false, count: 12)

    private let fullTitle = "Unlock Premium"
    private let goldColor = Color(red: 0.85, green: 0.7, blue: 0.3)
    private let goldLight = Color(red: 1.0, green: 0.88, blue: 0.55)

    public init(theme: EStoreTheme? = nil, onDismiss: (() -> Void)? = nil) {
        _data = StateObject(wrappedValue: EPaywallData(theme: theme, onDismiss: onDismiss))
    }

    public var body: some View {
        let t = data.theme
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()

            // Sparkle particles
            EPaywall14SparkleField(goldColor: goldColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button { data.onDismiss?() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Animated diamond icon
                        VStack(spacing: 16) {
                            ZStack {
                                // Glow behind
                                Circle()
                                    .fill(goldColor.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 25)

                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [goldLight, goldColor, goldColor.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .scaleEffect(diamondScale)
                                    .rotationEffect(.degrees(diamondRotation))
                            }
                            .padding(.top, 16)

                            // Typewriter text
                            Text(displayedText)
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [goldLight, goldColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 40)

                            Text("Experience the finest features")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(1.2), value: appeared)
                        }

                        // Features
                        VStack(spacing: 14) {
                            ForEach(Array(data.features.enumerated()), id: \.offset) { index, feature in
                                EPaywall14FeatureRow(icon: feature.icon, text: feature.title, goldColor: goldColor, appeared: appeared, delay: 0.8 + Double(index) * 0.1)
                            }
                        }
                        .padding(.horizontal)

                        // Product cards with animated gold border
                        VStack(spacing: 12) {
                            ForEach(data.premiumProducts) { product in
                                let isSelected = selectedId == product.id ||
                                    (selectedId == nil && product.id == data.premiumProducts.first?.id)

                                EPaywall14ProductCard(
                                    product: product,
                                    isSelected: isSelected,
                                    goldColor: goldColor,
                                    goldLight: goldLight
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedId = product.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(1.2), value: appeared)

                        // Gold CTA
                        Button {
                            let id = selectedId ?? data.premiumProducts.first?.id ?? ""
                            Task { await data.purchase(id) }
                        } label: {
                            HStack {
                                if data.isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Subscribe Now")
                                        .fontWeight(.bold)
                                        .font(.title3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [goldLight, goldColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(16)
                        }
                        .disabled(data.isLoading)
                        .padding(.horizontal)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(1.4), value: appeared)

                        Button("Restore Purchases") {
                            Task { await data.restore() }
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            appeared = true

            // Diamond animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.5).delay(0.2)) {
                diamondScale = 1.0
                diamondRotation = 0
            }

            // Typewriter effect
            for (i, char) in fullTitle.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.06) {
                    displayedText += String(char)
                }
            }
        }
    }
}

// MARK: - Sparkle Field

private struct EPaywall14SparkleField: View {
    let goldColor: Color
    @State private var sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<15, id: \.self) { i in
                let sparkle = sparkles.indices.contains(i) ? sparkles[i] : (x: CGFloat(0), y: CGFloat(0), size: CGFloat(2), delay: 0.0)
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size))
                    .foregroundColor(goldColor.opacity(animate ? 0.7 : 0.1))
                    .position(x: sparkle.x, y: sparkle.y)
                    .animation(
                        .easeInOut(duration: Double.random(in: 1.5...3.0))
                            .repeatForever(autoreverses: true)
                            .delay(sparkle.delay),
                        value: animate
                    )
            }
            .onAppear {
                sparkles = (0..<15).map { _ in
                    (
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height),
                        size: CGFloat.random(in: 6...14),
                        delay: Double.random(in: 0...2)
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animate = true
                }
            }
        }
    }
}

// MARK: - Feature Row

private struct EPaywall14FeatureRow: View {
    let icon: String
    let text: String
    let goldColor: Color
    let appeared: Bool
    let delay: Double

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(goldColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -15)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }
}

// MARK: - Product Card with Rotating Gold Border

private struct EPaywall14ProductCard: View {
    let product: EStoreProduct
    let isSelected: Bool
    let goldColor: Color
    let goldLight: Color
    let action: () -> Void

    @State private var borderRotation: Double = 0

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
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(goldColor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ?
                        AnyShapeStyle(AngularGradient(
                            colors: [goldLight, goldColor, goldColor.opacity(0.2), goldLight],
                            center: .center,
                            angle: .degrees(borderRotation)
                        )) :
                        AnyShapeStyle(Color.white.opacity(0.08)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                borderRotation = 360
            }
        }
    }
}
