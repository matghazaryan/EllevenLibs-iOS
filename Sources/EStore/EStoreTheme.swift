import SwiftUI

/// Theme configuration for EStore paywalls.
/// Pass your app's colors and paywalls auto-build with your brand.
///
/// Usage:
///     // Minimal - just pass primary color
///     EStoreTheme(primaryColor: .blue)
///
///     // Full customization
///     EStoreTheme(
///         primaryColor: .purple,
///         accentColor: .orange,
///         backgroundColor: .black,
///         textColor: .white
///     )
public struct EStoreTheme {
    public var primaryColor: Color
    public var accentColor: Color
    public var backgroundColor: Color
    public var textColor: Color
    public var secondaryTextColor: Color
    public var cardBackgroundColor: Color
    public var cornerRadius: CGFloat

    public init(
        primaryColor: Color = .blue,
        accentColor: Color = .orange,
        backgroundColor: Color = Color(white: 1.0),
        textColor: Color = .primary,
        secondaryTextColor: Color = .secondary,
        cardBackgroundColor: Color = Color(white: 0.95),
        cornerRadius: CGFloat = 16
    ) {
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.cardBackgroundColor = cardBackgroundColor
        self.cornerRadius = cornerRadius
    }

    public static let `default` = EStoreTheme()
}
