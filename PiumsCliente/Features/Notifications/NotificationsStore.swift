// NotificationsStore.swift — contador global de notificaciones no leídas
// Accesible desde cualquier vista sin acoplamiento directo a NotificationsViewModel.
import Foundation

extension Notification.Name {
    static let notificationsCountUpdated = Notification.Name("notifications.count.updated")
}

@Observable
@MainActor
final class NotificationsStore {
    static let shared = NotificationsStore()

    var unreadCount: Int = 0
    private var isStarted = false

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true

        // Cuando llega una push no-chat → refrescar
        NotificationCenter.default.addObserver(
            forName: .notificationsNeedRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }

        Task { await refresh() }
    }

    // Llama la primera página de notificaciones y cuenta las no leídas.
    // No hay endpoint dedicado de unread-count para notificaciones, así que
    // usamos la primera página (20 items). Suficiente para el indicador visual.
    func refresh() async {
        do {
            let res: NotificationsResponse = try await APIClient.request(.listNotifications(page: 1))
            unreadCount = res.notifications.filter { !$0.isRead }.count
        } catch {
            // Ignore — el contador permanece con el valor anterior
        }
    }

    // Llamado desde NotificationsViewModel tras marcar todas leídas,
    // para que la campana se apague sin esperar otro fetch de red.
    func setZero() {
        unreadCount = 0
    }
}
