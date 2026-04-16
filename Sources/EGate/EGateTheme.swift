import SwiftUI

/// Theme configuration for EGate UI.
///
/// Usage:
///     // Minimal
///     EGateTheme(primaryColor: .blue)
///
///     // Full customization
///     EGateTheme(
///         backgroundColor: .black.opacity(0.9),
///         cardBackgroundColor: Color(white: 0.15),
///         titleColor: .white,
///         messageColor: .gray,
///         premiumButtonColor: .orange,
///         premiumButtonTextColor: .white,
///         adButtonColor: .clear,
///         adButtonTextColor: .blue,
///         adButtonBorderColor: .blue,
///         adButtonBorderWidth: 2,
///         dismissButtonColor: .gray,
///         cornerRadius: 20,
///         iconName: "gamecontroller.fill"
///     )
public struct EGateTheme {
    public var backgroundColor: Color
    public var cardBackgroundColor: Color
    public var titleColor: Color
    public var messageColor: Color
    public var premiumButtonColor: Color
    public var premiumButtonTextColor: Color
    public var adButtonColor: Color
    public var adButtonTextColor: Color
    public var adButtonBorderColor: Color
    public var adButtonBorderWidth: CGFloat
    public var dismissButtonColor: Color
    public var cornerRadius: CGFloat
    public var iconName: String
    public var iconColor: Color
    public var overlayColor: Color

    public init(
        backgroundColor: Color = Color(.systemBackground),
        cardBackgroundColor: Color = Color(.secondarySystemBackground),
        titleColor: Color = .primary,
        messageColor: Color = .secondary,
        premiumButtonColor: Color = .orange,
        premiumButtonTextColor: Color = .white,
        adButtonColor: Color = .clear,
        adButtonTextColor: Color = .blue,
        adButtonBorderColor: Color = .blue,
        adButtonBorderWidth: CGFloat = 1.5,
        dismissButtonColor: Color = .secondary,
        cornerRadius: CGFloat = 16,
        iconName: String = "gamecontroller.fill",
        iconColor: Color = .orange,
        overlayColor: Color = Color.black.opacity(0.5)
    ) {
        self.backgroundColor = backgroundColor
        self.cardBackgroundColor = cardBackgroundColor
        self.titleColor = titleColor
        self.messageColor = messageColor
        self.premiumButtonColor = premiumButtonColor
        self.premiumButtonTextColor = premiumButtonTextColor
        self.adButtonColor = adButtonColor
        self.adButtonTextColor = adButtonTextColor
        self.adButtonBorderColor = adButtonBorderColor
        self.adButtonBorderWidth = adButtonBorderWidth
        self.dismissButtonColor = dismissButtonColor
        self.cornerRadius = cornerRadius
        self.iconName = iconName
        self.iconColor = iconColor
        self.overlayColor = overlayColor
    }

    public static let `default` = EGateTheme()
}
