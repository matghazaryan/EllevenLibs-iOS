import SwiftUI

struct EPaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let theme: EStoreTheme

    init(icon: String = "checkmark.circle.fill", title: String, subtitle: String? = nil, theme: EStoreTheme) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.primaryColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
            Spacer()
        }
    }
}
