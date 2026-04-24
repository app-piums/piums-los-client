// PaymentsViewModel.swift
import Foundation

// MARK: - Payment Models

struct Payment: Codable, Identifiable {
    let id: String
    let bookingId: String?
    let clientId: String?
    let amount: Int           // en centavos
    let currency: String
    let status: PaymentStatusDetail
    let paymentMethod: String?
    let description: String?
    let stripePaymentIntentId: String?
    let createdAt: String
    let updatedAt: String?
}

enum PaymentStatusDetail: String, Codable {
    case pending    = "PENDING"
    case processing = "PROCESSING"
    case succeeded  = "SUCCEEDED"
    case failed     = "FAILED"
    case cancelled  = "CANCELLED"
    case refunded   = "REFUNDED"

    var displayName: String {
        switch self {
        case .pending:    return "Pendiente"
        case .processing: return "Procesando"
        case .succeeded:  return "Completado"
        case .failed:     return "Fallido"
        case .cancelled:  return "Cancelado"
        case .refunded:   return "Reembolsado"
        }
    }

    var color: String {
        switch self {
        case .pending:    return "orange"
        case .processing: return "blue"
        case .succeeded:  return "green"
        case .failed:     return "red"
        case .cancelled:  return "gray"
        case .refunded:   return "purple"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:    return "clock"
        case .processing: return "arrow.trianglehead.2.clockwise"
        case .succeeded:  return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        case .cancelled:  return "minus.circle.fill"
        case .refunded:   return "arrow.uturn.backward.circle.fill"
        }
    }
}

struct PaymentsResponse: Codable {
    let payments: [Payment]?
    let data: [Payment]?
    let pagination: SearchPagination?
    let total: Int?

    var allPayments: [Payment] { payments ?? data ?? [] }
}

struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let paymentIntentId: String
    let amount: Int
    let currency: String
}

// MARK: - ViewModel

@Observable
@MainActor
final class PaymentsViewModel {
    var payments: [Payment] = []
    var isLoading = false
    var errorMessage: String?
    var hasMore = true
    private var currentPage = 1

    func loadInitial() async {
        currentPage = 1
        payments = []
        hasMore = true
        await loadNext()
    }

    func loadNextIfNeeded(item: Payment) async {
        guard let last = payments.last, last.id == item.id, hasMore, !isLoading else { return }
        await loadNext()
    }

    private func loadNext() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: PaymentsResponse = try await APIClient.request(.listPayments(page: currentPage))
            payments.append(contentsOf: res.allPayments)
            hasMore = res.pagination?.hasMore ?? false
            currentPage += 1
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func formattedAmount(_ cents: Int, currency: String = "USD") -> String {
        let amount = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
