//
//  EllevenLibsExampleApp.swift
//  EllevenLibsExample
//
//  Created by Matevos Ghazaryan on 3/12/26.
//

import SwiftUI
import EAds
import EStore

@main
struct EllevenLibsExampleApp: App {
    init() {
        EAds.configure(
            banner: EAdUnitId(
                debug: "ca-app-pub-3940256099942544/2934735716",
                production: "ca-app-pub-xxxxxxxxxxxxx/1111111111"
            ),
            interstitial: EAdUnitId(
                debug: "ca-app-pub-3940256099942544/4411468910",
                production: "ca-app-pub-xxxxxxxxxxxxx/2222222222"
            ),
            rewarded: EAdUnitId(
                debug: "ca-app-pub-3940256099942544/1712485313",
                production: "ca-app-pub-xxxxxxxxxxxxx/3333333333"
            ),
            openApp: EAdUnitId(
                debug: "ca-app-pub-3940256099942544/5575463023",
                production: "ca-app-pub-xxxxxxxxxxxxx/4444444444"
            )
        )

        Task {
            await EStore.shared.configure(EStoreConfig(
                products: [
                    EStoreProductConfig(
                        id: "com.ellevenstudio.example.monthly",
                        type: .subscription,
                        localizedTitles: ["en": "Monthly Premium", "hy": "\u{0531}\u{0574}\u{057D}\u{0561}\u{056F}\u{0561}\u{0576}"],
                        localizedDescriptions: ["en": "Monthly access to all premium features"]
                    ),
                    EStoreProductConfig(
                        id: "com.ellevenstudio.example.yearly",
                        type: .subscription,
                        localizedTitles: ["en": "Yearly Premium"],
                        localizedDescriptions: ["en": "Yearly access to all premium features"]
                    ),
                    EStoreProductConfig(
                        id: "com.ellevenstudio.example.lifetime",
                        type: .oneTime,
                        localizedTitles: ["en": "Lifetime Premium"],
                        localizedDescriptions: ["en": "Lifetime access to all premium features"]
                    ),
                    EStoreProductConfig(
                        id: "com.ellevenstudio.example.coins100",
                        type: .consumable(amount: 100),
                        localizedTitles: ["en": "100 Coins"],
                        localizedDescriptions: ["en": "Buy 100 coins"]
                    ),
                    EStoreProductConfig(
                        id: "com.ellevenstudio.example.coins500",
                        type: .consumable(amount: 500),
                        localizedTitles: ["en": "500 Coins"],
                        localizedDescriptions: ["en": "Buy 500 coins"]
                    ),
                ],
                features: [
                    EStoreFeature(icon: "nosign", title: "Ad Free", subtitle: "Enjoy an ad-free experience"),
                    EStoreFeature(icon: "folder.fill", title: "Unlimited Projects", subtitle: "Create without limits"),
                    EStoreFeature(icon: "icloud.fill", title: "Cloud Sync", subtitle: "Access your data everywhere"),
                    EStoreFeature(icon: "bolt.fill", title: "Priority Support", subtitle: "Get help within hours"),
                    EStoreFeature(icon: "sparkles", title: "Exclusive Content", subtitle: "Access premium-only features"),
                    EStoreFeature(icon: "person.2.fill", title: "Family Sharing", subtitle: "Share with up to 6 family members"),
                ],
                theme: EStoreTheme(
                    primaryColor: .purple,
                    accentColor: .orange
                )
            ))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
