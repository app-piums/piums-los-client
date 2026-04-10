// QuejasViewModel.swift
import Foundation

// MARK: - Dispute Models

struct Dispute: Codable, Identifiable, Hashable {
    let id: String
    let bookingId: String
    let reportedBy: String
    let reportedAgainst: String?
    let disputeType: DisputeType
    let status: DisputeStatus
    let subject: String
    let description: String
    let resolution: DisputeResolution?
    let resolutionNotes: String?
    let priority: Int
    let messages: [DisputeMessage]?
    let refundAmount: Int?
    let refundIssued: Bool?
    let createdAt: String
    let updatedAt: String

    static func == (lhs: Dispute, rhs: Dispute) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct DisputeMessage: Codable, Identifiable {
    let id: String
    let disputeId: String
    let senderId: String
    let senderRole: String?
    let message: String
    let createdAt: String
}

struct DisputesResponse: Codable {
    let disputes: [Dispute]
    let pagination: SearchPagination?
    let data: [Dispute]?
    var allDisputes: [Dispute] { disputes.isEmpty ? (data ?? []) : disputes }
}

enum DisputeType: String, Codable, CaseIterable {
    case cancellation  = "CANCELLATION"
    case quality       = "QUALITY"
    case refund        = "REFUND"
    case noShow        = "NO_SHOW"
    case artistNoShow  = "ARTIST_NO_SHOW"
    case pricing       = "PRICING"
    case behavior      = "BEHAVIOR"
    case other         = "OTHER"

    var displayName: String {
        switch self {
        case .cancellation: return "Cancelación"
        case .quality:      return "Calidad del servicio"
        case .refund:       return "Reembolso"
        case .noShow:       return "No me presenté"
        case .artistNoShow: return "Artista no se presentó"
        case .pricing:      return "Precio / cargos"
        case .behavior:     return "Comportamiento"
        case .other:        return "Otro"
        }
    }

    var systemImage: String {
        switch self {
        case .cancellation: return "xmark.circle"
        case .quality:      return "star.slash"
        case .refund:       return "arrow.uturn.backward.circle"
        case .noShow:       return "person.slash"
        case .artistNoShow: return "person.badge.minus"
        case .pricing:      return "creditcard.trianglebadge.exclamationmark"
        case .behavior:     return "exclamationmark.triangle"
        case .other:        return "questionmark.circle"
        }
    }
}

enum DisputeStatus: String, Codable {
    case open          = "OPEN"
    case inReview      = "IN_REVIEW"
    case awaitingInfo  = "AWAITING_INFO"
    case resolved      = "RESOLVED"
    case closed        = "CLOSED"
    case escalated     = "ESCALATED"

    var displayName: String {
        switch self {
        case .open:         return "Abierta"
        case .inReview:     return "En revisión"
        case .awaitingInfo: return "Esperando info"
        case .resolved:     return "Resuelta"
        case .closed:       return "Cerrada"
        case .escalated:    return "Escalada"
        }
    }

    var color: String {
        switch self {
        case .open:         return "orange"
        case .inReview:     return "blue"
        case .awaitingInfo: return "yellow"
        case .resolved:     return "green"
        case .closed:       return "gray"
        case .escalated:    return "red"
        }
    }
}

enum DisputeResolution: String, Codable {
    case fullRefund    = "FULL_REFUND"
    case partialRefund = "PARTIAL_REFUND"
    case noRefund      = "NO_REFUND"
    case credit        = "CREDIT"
    case warning       = "WARNING"
    case suspension    = "SUSPENSION"
    case ban           = "BAN"
    case noAction      = "NO_ACTION"

    var displayName: String {
        switch self {
        case .fullRefund:    return "Reembolso completo"
        case .partialRefund: return "Reembolso parcial"
        case .noRefund:      return "Sin reembolso"
        case .credit:        return "Crédito para futura reserva"
        case .warning:       return "Advertencia emitida"
        case .suspension:    return "Suspensión temporal"
        case .ban:           return "Expulsión permanente"
        case .noAction:      return "Sin acción necesaria"
        }
    }
}

// MARK: - List ViewModel

@Observable
@MainActor
final class QuejasViewModel {
    var disputes: [Dispute] = []
    var isLoading = false
    var errorMessage: String?
    var hasMore = true
    private var currentPage = 1

    func loadInitial() async {
        currentPage = 1
        disputes = []
        hasMore = true
        await loadNext()
    }

    func loadNextIfNeeded(item: Dispute) async {
        guard let last = disputes.last, last.id == item.id, hasMore, !isLoading else { return }
        await loadNext()
    }

    private func loadNext() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: DisputesResponse = try await APIClient.request(
                .listMyDisputes(page: currentPage)
            )
            disputes.append(contentsOf: res.allDisputes)
            hasMore = res.pagination?.hasMore ?? false
            currentPage += 1
        } catch {
            if disputes.isEmpty { disputes = [] }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}

// MARK: - Create ViewModel

@Observable
@MainActor
final class CreateQuejaViewModel {
    let booking: Booking

    var disputeType: DisputeType = .other
    var subject = ""
    var description = ""
    var isLoading = false
    var errorMessage: String?
    var isSuccess = false
    var createdDispute: Dispute?

    init(booking: Booking) { self.booking = booking }

    var canSubmit: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func submit() async {
        guard canSubmit else {
            errorMessage = "Completa el asunto y la descripción"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let payload: [String: Any] = [
            "bookingId":   booking.id,
            "disputeType": disputeType.rawValue,
            "subject":     subject.trimmingCharacters(in: .whitespaces),
            "description": description.trimmingCharacters(in: .whitespaces)
        ]
        do {
            let dispute: Dispute = try await APIClient.request(.createDispute(payload: payload))
            createdDispute = dispute
            isSuccess = true
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }
}

// MARK: - Detail ViewModel

@Observable
@MainActor
final class DisputeDetailViewModel {
    var dispute: Dispute
    var newMessage = ""
    var isSendingMessage = false
    var errorMessage: String?

    init(dispute: Dispute) { self.dispute = dispute }

    func sendMessage() async {
        let text = newMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSendingMessage = true
        errorMessage = nil
        defer { isSendingMessage = false }
        do {
            let updated: Dispute = try await APIClient.request(
                .addDisputeMessage(id: dispute.id, message: text)
            )
            dispute = updated
            newMessage = ""
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func refresh() async {
        do {
            let updated: Dispute = try await APIClient.request(.getDispute(id: dispute.id))
            dispute = updated
        } catch { /* silently fail */ }
    }
}
