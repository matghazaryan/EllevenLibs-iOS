import SwiftUI

struct EPaywallCTAButton: View {
    let title: String
    let theme: EStoreTheme
    let isLoading: Bool
    let action: () -> Void

    init(_ title: String, theme: EStoreTheme, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.theme = theme
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(theme.cornerRadius)
        }
        .disabled(isLoading)
    }
}
