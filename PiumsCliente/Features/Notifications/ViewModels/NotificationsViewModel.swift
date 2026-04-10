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


