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
            if let count = note.object as? Int {
                self?.unreadCount = count
            }
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
