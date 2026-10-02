//
//  ProStore.swift
//  NII App
//
//  NII Pro — monthly auto-renewable subscription through the App Store (StoreKit 2).
//  Apple requires In-App Purchase for digital subscriptions sold inside an iOS app.
//

import Foundation
import StoreKit

@MainActor
final class ProStore: ObservableObject {
    @Published private(set) var product: StoreKit.Product?
    @Published private(set) var isActive = false
    @Published private(set) var renewsOn: Date?
    @Published var isBusy = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    init() {
        // Renewals, purchases from other devices, refunds
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    deinit { updates?.cancel() }

    var priceText: String { product?.displayPrice ?? "$39.99" }

    func load() async {
        do {
            product = try await StoreKit.Product.products(for: [NIIConfig.proProductID]).first
        } catch {
            message = "App Store недоступен: \(error.localizedDescription)"
        }
        await refresh()
    }

    func refresh() async {
        var active = false
        var date: Date?
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == NIIConfig.proProductID, t.revocationDate == nil {
                active = true
                date = t.expirationDate
            }
        }
        isActive = active
        renewsOn = date
    }

    func buy() async {
        guard let product else {
            message = "Подписка пока недоступна. Попробуйте позже."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                    message = "NII Pro подключён. Спасибо!"
                } else {
                    message = "Покупку не удалось проверить."
                }
            case .pending:
                message = "Покупка ожидает подтверждения (например, «Попросить купить»)."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        isBusy = true
        defer { isBusy = false }
        try? await AppStore.sync()
        await refresh()
        message = isActive ? "Подписка восстановлена." : "Активная подписка не найдена."
    }
}
