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
    }

    private static let countKey = "tipJarCount"

    private(set) var products: [Tier: Product] = [:]
    private(set) var phase: Phase = .idle
    private(set) var tipCount: Int
    private var observer: Task<Void, Never>?

    private init() {
        tipCount = UserDefaults.standard.integer(forKey: Self.countKey)
    }

    /// Call at launch: an Ask to Buy approval or a purchase interrupted by a quit arrives
    /// through `Transaction.updates`, and a consumable left unfinished is redelivered forever.
    func startObservingTransactions() {
        guard observer == nil else { return }
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

    func loadProducts() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: Tier.allCases.map(\.productID))) ?? []
        products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
            Tier.allCases.first { $0.productID == product.id }.map { ($0, product) }
        })
    }

    func purchase(_ tier: Tier) async {
        guard let product = products[tier], phase != .purchasing(tier) else { return }
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
        guard case .verified(let transaction) = result,
              Tier.allCases.contains(where: { $0.productID == transaction.productID })
        else { return }
        if transaction.revocationDate == nil {
            tipCount += 1
            UserDefaults.standard.set(tipCount, forKey: Self.countKey)
            phase = .thanked
        }
        await transaction.finish()
    }
}
