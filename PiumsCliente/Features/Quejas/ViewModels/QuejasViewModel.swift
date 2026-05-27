// QuejasViewModel.swift
// Los modelos Dispute, DisputeMessage, DisputeStatus, DisputesResponse están en Models.swift
import Foundation

// MARK: - DisputeType (local a este feature)

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

// MARK: - List ViewModel

@Observable
@MainActor
final class QuejasViewModel {
    var disputes: [Dispute] = []
    var isLoading = false
    var errorMessage: String?

    func loadInitial() async {
        disputes = []
        await load()
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: DisputesResponse = try await APIClient.request(.listMyDisputes)
            disputes = res.allDisputes
        } catch {
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
        guard canSubmit else { errorMessage = "Completa el asunto y la descripción"; return }
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
            let updated: Dispute = try await APIClient.request(.addDisputeMessage(id: dispute.id, message: text))
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
