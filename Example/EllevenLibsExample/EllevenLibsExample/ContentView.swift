//
//  ContentView.swift
//  EllevenLibsExample
//
//  Created by Matevos Ghazaryan on 3/12/26.
//

import SwiftUI
import EllevenLibs
import EAds
import EStore

struct ContentView: View {
    @ObservedObject private var store = EStore.shared
    @State private var showPaywall: Int = 0

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Library Info
                Section("Library Info") {
                    LabeledContent("Version", value: EllevenLibs.version)
                    LabeledContent("Premium", value: store.isPremium ? "Yes" : "No")
                    LabeledContent("Coins (100)", value: "\(store.consumableBalance(for: "com.ellevenstudio.example.coins100"))")
                    LabeledContent("Coins (500)", value: "\(store.consumableBalance(for: "com.ellevenstudio.example.coins500"))")
                }

                // MARK: - Ads
                Section("EAds - Banner") {
                    EAdsBanner()
                        .frame(height: 50)
                }

                Section("EAds - Fullscreen") {
                    Button("Show Interstitial") {
                        EAdsInterstitial.shared.show()
                    }
                    Button("Show Rewarded Ad") {
                        EAdsRewarded.shared.show { reward in
                            print("Reward earned: \(reward.amount) \(reward.type)")
                        }
                    }
                    Button("Show Open App Ad") {
                        EAdsOpenApp.shared.show()
                    }
                }

                // MARK: - Paywalls
                Section("EStore - Paywalls") {
                    ForEach(1...10, id: \.self) { i in
                        Button("Paywall \(i)\(i == 10 ? " (Coin Store)" : "")") {
                            showPaywall = i
                        }
                    }
                }

                Section("EStore - Fancy Paywalls") {
                    Button("Paywall 11 - Animated Gradient") { showPaywall = 11 }
                    Button("Paywall 12 - Floating Particles") { showPaywall = 12 }
                    Button("Paywall 13 - Glassmorphism") { showPaywall = 13 }
                    Button("Paywall 14 - Dark Luxury") { showPaywall = 14 }
                    Button("Paywall 15 - 3D Interactive") { showPaywall = 15 }
                }

                // MARK: - Store Products
                Section("EStore - Products") {
                    if store.products.isEmpty {
                        Text("No products loaded")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.products) { product in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(product.localizedTitle)
                                        .font(.headline)
                                    Text(product.localizedDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(product.displayPrice) {
                                    Task {
                                        try? await EStore.shared.purchase(product.id)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                // MARK: - Store Actions
                Section("EStore - Actions") {
                    Button("Restore Purchases") {
                        Task { try? await EStore.shared.restore() }
                    }
                    Button("Verify Premium Status") {
                        Task { await EStore.shared.verifyPremiumStatus() }
                    }
                }

                // MARK: - Purchase Info
                if let info = store.purchaseInfo {
                    Section("EStore - Active Purchase") {
                        LabeledContent("Product ID", value: info.productId)
                        LabeledContent("Purchase Date", value: info.purchaseDate.formatted())
                        if let expiration = info.expirationDate {
                            LabeledContent("Expiration", value: expiration.formatted())
                        }
                        LabeledContent("Transaction ID", value: "\(info.transactionId)")
                    }
                }
            }
            .navigationTitle("EllevenLibs Example")
            .fullScreenCover(isPresented: Binding(
                get: { showPaywall > 0 },
                set: { if !$0 { showPaywall = 0 } }
            )) {
                paywallView(for: showPaywall)
            }
        }
    }

    @ViewBuilder
    func paywallView(for index: Int) -> some View {
        let dismiss = { showPaywall = 0 }
        switch index {
        case 1: EPaywall1(onDismiss: dismiss)
        case 2: EPaywall2(onDismiss: dismiss)
        case 3: EPaywall3(onDismiss: dismiss)
        case 4: EPaywall4(onDismiss: dismiss)
        case 5: EPaywall5(onDismiss: dismiss)
        case 6: EPaywall6(onDismiss: dismiss)
        case 7: EPaywall7(onDismiss: dismiss)
        case 8: EPaywall8(onDismiss: dismiss)
        case 9: EPaywall9(onDismiss: dismiss)
        case 10: EPaywall10(onDismiss: dismiss)
        case 11: EPaywall11(onDismiss: dismiss)
        case 12: EPaywall12(onDismiss: dismiss)
        case 13: EPaywall13(onDismiss: dismiss)
        case 14: EPaywall14(onDismiss: dismiss)
        case 15: EPaywall15(onDismiss: dismiss)
        default: EmptyView()
        }
    }
}

#Preview {
    ContentView()
}
