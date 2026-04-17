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
///         textColor: .white,
///         fontName: "Noteworthy",
///         backgroundImageName: "bg_premium"
///     )
public struct EStoreTheme {
    public var primaryColor: Color
    public var accentColor: Color
    public var backgroundColor: Color
    public var textColor: Color
    public var secondaryTextColor: Color
    public var cardBackgroundColor: Color
    public var cornerRadius: CGFloat
    public var fontName: String?
    public var backgroundImageName: String?
    public var termsURL: URL?
    public var privacyURL: URL?

    public init(
        primaryColor: Color = .blue,
        accentColor: Color = .orange,
        backgroundColor: Color = Color(white: 1.0),
        textColor: Color = .primary,
        secondaryTextColor: Color = .secondary,
        cardBackgroundColor: Color = Color(white: 0.95),
        cornerRadius: CGFloat = 16,
        fontName: String? = nil,
        backgroundImageName: String? = nil,
        termsURL: URL? = nil,
        privacyURL: URL? = nil
    ) {
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.cardBackgroundColor = cardBackgroundColor
        self.cornerRadius = cornerRadius
        self.fontName = fontName
        self.backgroundImageName = backgroundImageName
        self.termsURL = termsURL
        self.privacyURL = privacyURL
    }

    public static let `default` = EStoreTheme()

    /// Returns a Font using the custom fontName if set, otherwise system font.
    public func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight)
    }

    /// Whether terms or privacy links are available.
    public var hasLegalLinks: Bool {
        termsURL != nil || privacyURL != nil
    }
}
