import SwiftUI
import EStore

/// Full-screen gate view shown when the play limit is reached.
/// Offers premium upgrade, watch ad, or dismiss options.
///
/// Usage:
///     // Default — uses EGate.shared config
///     EGateView(onDismiss: { ... })
///
///     // Custom config
///     EGateView(config: myConfig, onDismiss: { ... })
///
///     // Custom paywall
///     EGateView(onPremiumTapped: { showMyPaywall() }, onDismiss: { ... })
public struct EGateView: View {
    private let config: EGateConfig
    private let onPremiumTapped: (() -> Void)?
    private let onAdTapped: (() -> Void)?
    private let onDismiss: (() -> Void)?
    @State private var showPaywall = false

    /// - Parameters:
    ///   - config: Gate configuration. Defaults to EGate.shared.config.
    ///   - onPremiumTapped: Custom handler for premium button. If nil, shows EPaywall1.
    ///   - onAdTapped: Custom handler for ad button. If nil, uses EGate.shared.showRewardedAd().
    ///   - onDismiss: Called when the gate is dismissed.
    public init(
        config: EGateConfig? = nil,
        onPremiumTapped: (() -> Void)? = nil,
        onAdTapped: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.config = config ?? EGate.shared.config
        self.onPremiumTapped = onPremiumTapped
        self.onAdTapped = onAdTapped
        self.onDismiss = onDismiss
    }

    public var body: some View {
        let t = config.theme

        ZStack {
            // Overlay background
            t.overlayColor
                .ignoresSafeArea()
                .onTapGesture {} // Block taps through

            // Card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: t.iconName)
                    .font(.system(size: 56))
                    .foregroundColor(t.iconColor)
                    .padding(.top, 28)

                // Title
                Text(config.title)
                    .font(.title2).bold()
                    .foregroundColor(t.titleColor)
                    .multilineTextAlignment(.center)

                // Message
                Text(config.message)
                    .font(.body)
                    .foregroundColor(t.messageColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(spacing: 12) {
                    // Premium button
                    if config.showPremiumButton {
                        Button {
                            if let onPremiumTapped {
                                onPremiumTapped()
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text(config.premiumButtonText)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(t.premiumButtonColor)
                            .foregroundColor(t.premiumButtonTextColor)
                            .cornerRadius(t.cornerRadius)
                        }
                    }

                    // Ad button
                    if config.showAdButton {
                        Button {
                            if let onAdTapped {
                                onAdTapped()
                            } else {
                                EGate.shared.showRewardedAd()
                                onDismiss?()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                Text(config.adButtonText)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(t.adButtonColor)
                            .foregroundColor(t.adButtonTextColor)
                            .cornerRadius(t.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: t.cornerRadius)
                                    .stroke(t.adButtonBorderColor, lineWidth: t.adButtonBorderWidth)
                            )
                        }
                    }

                    // Dismiss button
                    if config.showDismissButton {
                        Button {
                            onDismiss?()
                        } label: {
                            Text(config.dismissButtonText)
                                .font(.subheadline)
                                .foregroundColor(t.dismissButtonColor)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(t.cardBackgroundColor)
            .cornerRadius(t.cornerRadius + 4)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, 32)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            EPaywall1(onDismiss: {
                showPaywall = false
                // If user became premium, dismiss the gate too
                if EStore.shared.isPremium {
                    EGate.shared.onPremiumPurchased()
                    onDismiss?()
                }
            })
        }
    }
}

/// SwiftUI View modifier to automatically show EGateView when the gate is triggered.
///
/// Usage:
///     ContentView()
///         .eGate()
///
///     // With custom handlers
///     ContentView()
///         .eGate(onPremiumTapped: { showMyPaywall() })
public struct EGateModifier: ViewModifier {
    @ObservedObject private var gate = EGate.shared
    let config: EGateConfig?
    let onPremiumTapped: (() -> Void)?
    let onAdTapped: (() -> Void)?

    public func body(content: Content) -> some View {
        ZStack {
            content
            if gate.shouldShowGate {
                EGateView(
                    config: config,
                    onPremiumTapped: onPremiumTapped,
                    onAdTapped: onAdTapped,
                    onDismiss: { gate.dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gate.shouldShowGate)
    }
}

extension View {
    /// Attach the EGate overlay. When the play limit is reached, the gate view appears automatically.
    public func eGate(
        config: EGateConfig? = nil,
        onPremiumTapped: (() -> Void)? = nil,
        onAdTapped: (() -> Void)? = nil
    ) -> some View {
        modifier(EGateModifier(config: config, onPremiumTapped: onPremiumTapped, onAdTapped: onAdTapped))
    }
}
