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
            let _: EmptyResponse = try await APIClient.request(.markNotificationsRead(ids: [id]))
            if let idx = notifications.firstIndex(where: { $0.id == id }) {
                let n = notifications[idx]
                notifications[idx] = PiumsNotification(
                    id: n.id, title: n.title, message: n.message, type: n.type,
                    readAt: ISO8601DateFormatter().string(from: Date()),
                    data: n.data, createdAt: n.createdAt
                )
            }
            // Mantener el badge global en sincronía con el estado local
            if NotificationsStore.shared.unreadCount > 0 {
                NotificationsStore.shared.unreadCount -= 1
            }
        } catch { /* silently fail */ }
    }

    func markAllRead() async {
        let unreadIds = notifications.filter { !$0.isRead }.map { $0.id }
        guard !unreadIds.isEmpty else { return }
        do {
            let _: EmptyResponse = try await APIClient.request(.markNotificationsRead(ids: unreadIds))
            let now = ISO8601DateFormatter().string(from: Date())
            notifications = notifications.map { n in
                guard !n.isRead else { return n }
                return PiumsNotification(id: n.id, title: n.title, message: n.message,
                                         type: n.type, readAt: now, data: n.data, createdAt: n.createdAt)
            }
            // Apagar el badge de la campana sin esperar otro fetch de red
            NotificationsStore.shared.setZero()
        } catch { await loadInitial() }
    }

    func loadMoreIfNeeded(current: PiumsNotification) async {
        guard let last = notifications.last, last.id == current.id, hasMore else { return }
        await loadNext()
    }

    private func loadNext() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: NotificationsResponse = try await APIClient.request(
                .listNotifications(page: currentPage)
            )
            notifications.append(contentsOf: res.notifications)
            hasMore = res.pagination.hasMore
            currentPage += 1
            // Tras cargar la primera página sincronizamos el badge global.
            // Usamos el conteo local en lugar de hacer un fetch extra de red.
            if currentPage == 2 {
                NotificationsStore.shared.unreadCount = notifications.filter { !$0.isRead }.count
            }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
