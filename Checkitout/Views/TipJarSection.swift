//
//  TipJarSection.swift
//  Checkitout
//

import StoreKit
import SwiftUI

/// The 「開発を応援する」 section of About. Hidden until the products load, so a build
/// without them in App Store Connect shows nothing rather than dead rows.
struct TipJarSection: View {
    @State private var jar = TipJar.shared

    var body: some View {
        Group {
            if !jar.products.isEmpty {
                Section {
                    ForEach(TipJar.Tier.allCases) { tier in
                        if let product = jar.products[tier] {
                            TipRow(tier: tier, product: product, jar: jar)
                        }
                    }
                } header: {
                    Text("開発を応援する")
                } footer: {
                    TipJarFooter(phase: jar.phase, tipCount: jar.tipCount)
                }
            }
        }
        .task { await jar.loadProducts() }
    }
}

private struct TipRow: View {
    let tier: TipJar.Tier
    let product: Product
    let jar: TipJar

    var body: some View {
        Button {
            Task { await jar.purchase(tier) }
        } label: {
            HStack {
                Text(verbatim: tier.emoji)
                    .accessibilityHidden(true)
                Text(tier.title)
                    .foregroundStyle(.primary)
                Spacer()
                if jar.phase == .purchasing(tier) {
                    ProgressView()
                } else {
                    Text(verbatim: product.displayPrice)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(jar.phase == .purchasing(tier))
    }
}

private struct TipJarFooter: View {
    let phase: TipJar.Phase
    let tipCount: Int

    var body: some View {
        switch phase {
        case .thanked:
            Text("ありがとう！ ぼくら、もっといい音で鳴れるようにがんばるね。")
        case .failed:
            Text("購入が完了しませんでした。料金はかかっていません。")
        case .idle, .purchasing:
            if tipCount > 0 {
                Text("これまでに \(tipCount) 回応援してもらいました。ありがとう！")
            } else {
                Text("機能は増えないけれど、チェケラを続けていく励みになります。")
            }
        }
    }
}
