import SwiftUI

struct EPaywallCloseButton: View {
    let theme: EStoreTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }
}
