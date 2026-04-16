import SwiftUI

/// Configuration for EGate play-limit system.
///
/// Usage:
///     let config = EGateConfig(
///         maxPlays: 5,
///         storageKey: "my_game_gate",
///         localizedTitles: ["en": "Play Limit Reached", "hy": "\u{053D}\u{0561}\u{0572}\u{0565}\u{0580}\u{056B} \u{057D}\u{0561}\u{0570}\u{0574}\u{0561}\u{0576}\u{0561}\u{0583}\u{0561}\u{056F}\u{0568} \u{057D}\u{057A}\u{0561}\u{057C}\u{057E}\u{0561}\u{056E} \u{0567}"],
///         localizedMessages: ["en": "Upgrade to premium or watch an ad to continue playing."],
///         localizedPremiumButtonTexts: ["en": "Go Premium"],
///         localizedAdButtonTexts: ["en": "Watch Ad to Continue"],
///         localizedDismissButtonTexts: ["en": "Later"]
///     )
public struct EGateConfig {
    public let maxPlays: Int
    public let storageKey: String
    public let localizedTitles: [String: String]
    public let localizedMessages: [String: String]
    public let localizedPremiumButtonTexts: [String: String]
    public let localizedAdButtonTexts: [String: String]
    public let localizedDismissButtonTexts: [String: String]
    public let theme: EGateTheme
    public let showAdButton: Bool
    public let showPremiumButton: Bool
    public let showDismissButton: Bool
    public let resetAfterAd: Bool

    /// - Parameters:
    ///   - maxPlays: Number of plays before gate is shown. Default is 5.
    ///   - storageKey: Unique key for persisting play count. Default is "egate_play_count".
    ///   - localizedTitles: Title text by language code. Default: "Play Limit Reached".
    ///   - localizedMessages: Message text by language code. Default: "Upgrade to premium or watch an ad to continue playing."
    ///   - localizedPremiumButtonTexts: Premium button text by language code. Default: "Go Premium".
    ///   - localizedAdButtonTexts: Ad button text by language code. Default: "Watch Ad to Continue".
    ///   - localizedDismissButtonTexts: Dismiss button text by language code. Default: "Later".
    ///   - theme: Visual theme for the gate UI.
    ///   - showAdButton: Whether to show the "Watch Ad" button. Default true.
    ///   - showPremiumButton: Whether to show the "Go Premium" button. Default true.
    ///   - showDismissButton: Whether to show the "Later" dismiss button. Default true.
    ///   - resetAfterAd: Whether to reset play count after watching an ad. Default true.
    public init(
        maxPlays: Int = 5,
        storageKey: String = "egate_play_count",
        localizedTitles: [String: String] = ["en": "Play Limit Reached"],
        localizedMessages: [String: String] = ["en": "Upgrade to premium or watch an ad to continue playing."],
        localizedPremiumButtonTexts: [String: String] = ["en": "Go Premium"],
        localizedAdButtonTexts: [String: String] = ["en": "Watch Ad to Continue"],
        localizedDismissButtonTexts: [String: String] = ["en": "Later"],
        theme: EGateTheme = .default,
        showAdButton: Bool = true,
        showPremiumButton: Bool = true,
        showDismissButton: Bool = true,
        resetAfterAd: Bool = true
    ) {
        self.maxPlays = maxPlays
        self.storageKey = storageKey
        self.localizedTitles = localizedTitles
        self.localizedMessages = localizedMessages
        self.localizedPremiumButtonTexts = localizedPremiumButtonTexts
        self.localizedAdButtonTexts = localizedAdButtonTexts
        self.localizedDismissButtonTexts = localizedDismissButtonTexts
        self.theme = theme
        self.showAdButton = showAdButton
        self.showPremiumButton = showPremiumButton
        self.showDismissButton = showDismissButton
        self.resetAfterAd = resetAfterAd
    }

    // MARK: - Localized Accessors

    private var currentLanguage: String {
        String(Locale.current.language.languageCode?.identifier ?? "en")
    }

    public var title: String {
        localizedTitles[currentLanguage] ?? localizedTitles["en"] ?? localizedTitles.values.first ?? "Play Limit Reached"
    }

    public var message: String {
        localizedMessages[currentLanguage] ?? localizedMessages["en"] ?? localizedMessages.values.first ?? ""
    }

    public var premiumButtonText: String {
        localizedPremiumButtonTexts[currentLanguage] ?? localizedPremiumButtonTexts["en"] ?? localizedPremiumButtonTexts.values.first ?? "Go Premium"
    }

    public var adButtonText: String {
        localizedAdButtonTexts[currentLanguage] ?? localizedAdButtonTexts["en"] ?? localizedAdButtonTexts.values.first ?? "Watch Ad to Continue"
    }

    public var dismissButtonText: String {
        localizedDismissButtonTexts[currentLanguage] ?? localizedDismissButtonTexts["en"] ?? localizedDismissButtonTexts.values.first ?? "Later"
    }
}
