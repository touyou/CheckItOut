//
//  TipJar.swift
//  Checkitout
//

import Foundation
import Observation
import StoreKit

/// Consumable tips. A tip unlocks nothing (App Review rejects tips that gate features),
/// so the only state kept is how many times the person has tipped, on this device.
@MainActor
@Observable
final class TipJar {
    static let shared = TipJar()

    enum Tier: String, CaseIterable, Identifiable {
        case coffee, cake, lunch

        var id: String { productID }
        var productID: String { "com.dev.touyou.Checkitout.tip.\(rawValue)" }

        var title: LocalizedStringResource {
            switch self {
            case .coffee: "コーヒー一杯"
            case .cake: "ケーキも添えて"
            case .lunch: "お昼ごはん"
            }
        }

        var emoji: String {
            switch self {
            case .coffee: "☕️"
            case .cake: "🍰"
            case .lunch: "🍱"
            }
        }
    }

    enum Phase: Equatable {
        case idle
        case purchasing(Tier)
        case thanked
        case failed
        case unverified
    }

    private static let countKey = "tipJarCount"
    private static let handledKey = "tipJarHandledTransactionIDs"

    private(set) var products: [Tier: Product] = [:]
    private(set) var phase: Phase = .idle
    private(set) var tipCount: Int
    private var handledIDs: Set<String>
    private var observer: Task<Void, Never>?

    private init() {
        tipCount = UserDefaults.standard.integer(forKey: Self.countKey)
        handledIDs = Set(UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? [])
    }

    /// Call at launch: an Ask to Buy approval or a purchase interrupted by a quit arrives
    /// through `Transaction.updates`, and a consumable left unfinished is redelivered forever.
    func startObservingTransactions() {
        guard observer == nil else { return }
        Task { await loadProducts() }
        observer = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            for await result in Transaction.unfinished {
                await handle(result)
            }
        }
    }

    var isPurchasing: Bool {
        if case .purchasing = phase { true } else { false }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: Tier.allCases.map(\.productID))) ?? []
        products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
            Tier.allCases.first { $0.productID == product.id }.map { ($0, product) }
        })
    }

    func purchase(_ tier: Tier) async {
        guard let product = products[tier], !isPurchasing else { return }
        phase = .purchasing(tier)
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
            case .pending, .userCancelled:
                phase = .idle
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        let transaction: Transaction
        switch result {
        case .verified(let verified):
            transaction = verified
        case .unverified(let unverified, _):
            guard Self.isTip(unverified) else { return }
            // Not counted, but finished so it stops being redelivered on every launch.
            if isPurchasing { phase = .unverified }
            await unverified.finish()
            return
        }
        guard Self.isTip(transaction) else { return }
        // `updates` and `unfinished` both deliver the same transaction at launch, and a quit
        // between counting and finish() redelivers it, so each id is counted once.
        if transaction.revocationDate == nil, handledIDs.insert(String(transaction.id)).inserted {
            tipCount += 1
            UserDefaults.standard.set(tipCount, forKey: Self.countKey)
            UserDefaults.standard.set(Array(handledIDs), forKey: Self.handledKey)
            phase = .thanked
        } else if isPurchasing {
            phase = .idle
        }
        await transaction.finish()
    }

    private static func isTip(_ transaction: Transaction) -> Bool {
        Tier.allCases.contains { $0.productID == transaction.productID }
    }
}
