// TicketsViewModel.swift
import Foundation

private struct TicketPurchaseCheckoutResponse: Decodable {
    let purchase: TicketPurchase?
    let purchaseId: String?
    let redirectUrl: String?
    let paymentIntent: PaymentIntent?
}

@Observable
@MainActor
final class TicketsViewModel {

    // MARK: - Discovery (eventos públicos)
    var events: [TicketEvent] = []
    var isLoading = false
    var hasMore = true
    var errorMessage: String?
    private var currentPage = 1
    private let pageLimit = 12

    // MARK: - Mis boletos
    var myPurchases: [TicketPurchase] = []
    var isLoadingPurchases = false

    // MARK: - Compra en curso
    var redirectUrl: String?           // URL Tilopay para WebView
    var pendingPurchaseId: String?     // polling
    var purchaseCompleted: Bool = false
    var purchaseErrorMessage: String?
    var isPurchasing = false

    // MARK: - Discovery

    func loadInitial() async {
        currentPage = 1
        events = []
        hasMore = true
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: TicketEventsResponse = try await APIClient.request(
                .listTicketEvents(page: currentPage, limit: pageLimit)
            )
            let newEvents = res.all.filter { $0.isPublished || $0.isSoldOut }
            if currentPage == 1 {
                events = newEvents
            } else {
                events.append(contentsOf: newEvents)
            }
            hasMore = newEvents.count == pageLimit && (res.pagination?.hasMore ?? true)
            currentPage += 1
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func loadNextIfNeeded(item: TicketEvent) async {
        guard let last = events.last, last.id == item.id else { return }
        await loadNextPage()
    }

    // MARK: - Mis boletos

    func loadMyPurchases() async {
        isLoadingPurchases = true
        defer { isLoadingPurchases = false }
        do {
            let res: TicketPurchasesResponse = try await APIClient.request(.myTicketPurchases)
            myPurchases = res.all.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    // MARK: - Compra

    func purchaseTicket(
        event: TicketEvent,
        tier: TicketTier,
        quantity: Int,
        buyerName: String,
        buyerEmail: String,
        couponCode: String?
    ) async {
        isPurchasing = true
        purchaseErrorMessage = nil
        purchaseCompleted = false
        defer { isPurchasing = false }

        var payload: [String: Any] = [
            "tierId": tier.id,
            "quantity": quantity,
            "buyerName": buyerName,
            "buyerEmail": buyerEmail,
            "returnUrl": "piums://tickets/confirmacion"
        ]
        if let code = couponCode, !code.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["couponCode"] = code
        }

        do {
            let res: TicketPurchaseCheckoutResponse = try await APIClient.request(
                .purchaseTicket(eventId: event.id, payload: payload)
            )
            // Guardar purchaseId para polling
            pendingPurchaseId = res.purchase?.id ?? res.purchaseId
            // Obtener URL de redirección
            redirectUrl = res.redirectUrl ?? res.paymentIntent?.redirectUrl
        } catch {
            purchaseErrorMessage = AppError(from: error).errorDescription
        }
    }

    // MARK: - Polling tras pago

    func pollPurchaseStatus() async {
        guard let pid = pendingPurchaseId else { return }
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if let res: TicketPurchaseWrapper = try? await APIClient.request(.getTicketPurchase(id: pid)),
               let purchase = res.resolved {
                if purchase.isPaid {
                    purchaseCompleted = true
                    await loadMyPurchases()
                    return
                }
            }
        }
    }
}
