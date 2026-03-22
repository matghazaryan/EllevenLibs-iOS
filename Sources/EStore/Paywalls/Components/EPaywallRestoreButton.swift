import SwiftUI

struct EPaywallRestoreButton: View {
    let theme: EStoreTheme
    let action: () -> Void

    var body: some View {
        Button("Restore Purchases", action: action)
            .font(.footnote)
            .foregroundColor(theme.secondaryTextColor)
    }
}
