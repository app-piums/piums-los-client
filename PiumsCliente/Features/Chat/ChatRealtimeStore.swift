// ChatRealtimeStore.swift — unread badge + lifecycle
import Foundation
import SwiftUI

extension Notification.Name {
    static let chatUnreadNeedsRefresh = Notification.Name("chat.unread.needs.refresh")
}

@Observable
@MainActor
final class ChatRealtimeStore {
    static let shared = ChatRealtimeStore()

    private let socket = ChatSocketManager.shared
    private var isStarted = false

    var unreadCount: Int = 0
    var isConnected: Bool { socket.isConnected }
    // ID de conversación pendiente de abrir por deep link desde push
    var pendingDeepLinkConversationId: String?

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true
        socket.connect()

        NotificationCenter.default.addObserver(
            forName: .chatMessageReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshUnread() }
        }

        NotificationCenter.default.addObserver(
            forName: .chatUnreadNeedsRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshUnread() }
        }

        NotificationCenter.default.addObserver(
            forName: .chatUnreadCountUpdated,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let count = note.object as? Int else { return }
            Task { @MainActor [weak self] in self?.unreadCount = count }
        }

        // Guarda el ID para que ChatInboxView lo consuma al montarse,
        // incluso si la notificación llega antes de que la vista exista.
        NotificationCenter.default.addObserver(
            forName: .navigateToConversation,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let id = note.userInfo?["conversationId"] as? String
            Task { @MainActor [weak self] in self?.pendingDeepLinkConversationId = id }
        }
    }

    func setActive(_ active: Bool) {
        if active {
            socket.connect()
            Task { await refreshUnread() }
        } else {
            socket.disconnect()
        }
    }

    func refreshUnread() async {
        do {
            let res: UnreadCountResponse = try await APIClient.request(.unreadCount)
            unreadCount = res.unreadCount
        } catch {
            // ignore transient errors
        }
    }
}
