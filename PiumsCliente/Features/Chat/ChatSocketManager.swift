// ChatSocketManager.swift — Socket.IO realtime para chat
import Foundation
import SocketIO

extension Notification.Name {
    static let chatMessageReceived = Notification.Name("chat.message.received")
    static let chatMessageRead = Notification.Name("chat.message.read")
    static let chatUnreadCountUpdated = Notification.Name("chat.unread.count.updated")
}

@Observable
@MainActor
final class ChatSocketManager {
    static let shared = ChatSocketManager()
    private init() {}

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var currentToken: String?

    var isConnected = false

    func connect() {
        let token = TokenStorage.shared.accessToken ?? ""
        guard socket == nil || currentToken != token else { return }
        disconnect()

        guard let url = URL(string: socketUrlString()) else { return }
        let manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .forcePolling(false)
        ])
        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket
        currentToken = token

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = true }
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = false }
        }

        socket.on("message:received") { data, _ in
            if let msg = ChatSocketManager.decodeMessage(from: data) {
                NotificationCenter.default.post(name: .chatMessageReceived, object: msg)
            }
        }
        socket.on("message:read") { data, _ in
            if let dict = data.first as? [String: Any], let id = dict["messageId"] as? String {
                NotificationCenter.default.post(name: .chatMessageRead, object: id)
            }
        }
        socket.on("unread:count") { data, _ in
            if let dict = data.first as? [String: Any], let count = dict["unreadCount"] as? Int {
                NotificationCenter.default.post(name: .chatUnreadCountUpdated, object: count)
            }
        }

        // Autenticación via handshake auth.token
        socket.connect(withPayload: ["token": token])
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        currentToken = nil
    }

    func joinConversation(_ id: String) {
        socket?.emit("conversation:join", ["conversationId": id])
    }

    func leaveConversation(_ id: String) {
        socket?.emit("conversation:leave", ["conversationId": id])
    }

    func markConversationRead(_ id: String) {
        socket?.emit("conversation:read", ["conversationId": id])
    }

    func send(conversationId: String, content: String) {
        socket?.emit("message:send", [
            "conversationId": conversationId,
            "content": content,
            "type": "text"
        ])
    }

    private func socketUrlString() -> String {
        if let url = Bundle.main.infoDictionary?["CHAT_SOCKET_URL"] as? String {
            return url
        }
        return "http://localhost:4010"
    }

    // MARK: - Decoding helper

    private static func decodeMessage(from data: [Any]) -> ChatMessage? {
        // Puede venir {message: {...}} o {...}
        if let dict = data.first as? [String: Any] {
            if let msg = dict["message"] {
                return decodeChatMessage(from: msg)
            }
            return decodeChatMessage(from: dict)
        }
        return nil
    }

    private static func decodeChatMessage(from any: Any) -> ChatMessage? {
        guard let json = try? JSONSerialization.data(withJSONObject: any),
              let msg = try? JSONDecoder().decode(ChatMessage.self, from: json)
        else { return nil }
        return msg
    }
}
