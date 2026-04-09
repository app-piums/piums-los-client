// NotificationsViewModel.swift
import Foundation

@Observable
@MainActor
final class NotificationsViewModel {
    var notifications: [PiumsNotification] = []
    var isLoading = false
    var errorMessage: String?
    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    private var currentPage = 1
    var hasMore = true

    func loadInitial() async {
        currentPage = 1
        notifications = []
        hasMore = true
        await loadNext()
    }

    func markAsRead(id: String) async {
        do {
            let _: EmptyResponse = try await APIClient.request(.markNotificationRead(id: id))
            if let idx = notifications.firstIndex(where: { $0.id == id }) {
                notifications[idx] = PiumsNotification(
                    id: notifications[idx].id,
                    title: notifications[idx].title,
                    body: notifications[idx].body,
                    type: notifications[idx].type,
                    isRead: true,
                    data: notifications[idx].data,
                    createdAt: notifications[idx].createdAt
                )
            }
        } catch { /* silently fail */ }
    }

    func markAllRead() async {
        for n in notifications where !n.isRead {
            await markAsRead(id: n.id)
        }
    }

    private func loadNext() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: PaginatedResponse<PiumsNotification> = try await APIClient.request(
                .listNotifications(page: currentPage)
            )
            notifications.append(contentsOf: res.data)
            hasMore = res.hasMore
            currentPage += 1
        } catch {
            if notifications.isEmpty { notifications = PiumsNotification.mockList }
        }
    }
}

extension PiumsNotification {
    static var mockList: [PiumsNotification] {
        [
            PiumsNotification(id: "n1", title: "Reserva confirmada", body: "Carlos Méndez aceptó tu solicitud.", type: "BOOKING_CONFIRMED", isRead: false, data: ["bookingId": "b1"], createdAt: "2026-04-09T09:00:00Z"),
            PiumsNotification(id: "n2", title: "Pago procesado", body: "Tu pago de Q150.00 fue procesado.", type: "PAYMENT_COMPLETED", isRead: false, data: nil, createdAt: "2026-04-08T14:30:00Z"),
            PiumsNotification(id: "n3", title: "Nueva reseña", body: "Dejaste una reseña. ¡Gracias!", type: "NEW_REVIEW", isRead: true, data: nil, createdAt: "2026-04-07T18:00:00Z")
        ]
    }
}
