import SwiftUI

struct EPaywallProductCard: View {
    let product: EStoreProduct
    let isSelected: Bool
    let theme: EStoreTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.localizedTitle)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : theme.textColor)
                if let period = product.subscriptionPeriod {
                    Text(period)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : theme.secondaryTextColor)
                }
                Text(product.localizedDescription)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : theme.secondaryTextColor)
                    .lineLimit(2)
                Spacer()
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : theme.primaryColor)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.primaryColor : theme.cardBackgroundColor)
            .cornerRadius(theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
            )
        }
    }
}
