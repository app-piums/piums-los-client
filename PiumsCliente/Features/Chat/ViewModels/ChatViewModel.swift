// ChatViewModel.swift
import Foundation

@Observable
@MainActor
final class ChatViewModel {
    var conversations: [Conversation] = []
    var messages: [ChatMessage] = []
    var isLoading = false
    var errorMessage: String?
    var hasMore = true
    private var currentPage = 1
    private(set) var currentConversationId: String?

    private let socket = ChatSocketManager.shared
    private let unreadStore = ChatRealtimeStore.shared
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        socket.connect()
        unreadStore.startIfNeeded()

        observers.append(
            NotificationCenter.default.addObserver(forName: .chatMessageReceived, object: nil, queue: .main) { [weak self] note in
                guard let msg = note.object as? ChatMessage else { return }
                Task { @MainActor [weak self] in self?.handleIncoming(msg) }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(forName: .chatMessageRead, object: nil, queue: .main) { [weak self] note in
                guard let id = note.object as? String else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.messages = self.messages.map {
                        $0.id == id
                        ? ChatMessage(id: $0.id, conversationId: $0.conversationId, senderId: $0.senderId, content: $0.content, type: $0.type, status: "READ", readAt: $0.readAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
                        : $0
                    }
                }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(forName: .chatMessageError, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in
                    self?.errorMessage = note.object as? String ?? "Error al enviar mensaje"
                }
            }
        )
        // Re-fetch messages after reconnect to recover any missed during disconnect
        observers.append(
            NotificationCenter.default.addObserver(forName: .chatSocketReconnected, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let convId = self.currentConversationId else { return }
                    await self.loadMessages(conversationId: convId)
                }
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func loadConversations() async {
        currentPage = 1
        conversations = []
        hasMore = true
        await loadNextConversations()
    }

    func loadNextConversations() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: ConversationsResponse = try await APIClient.request(.listConversations(page: currentPage))
            conversations.append(contentsOf: res.conversations.filter {
                $0.status != "CLOSED" && $0.status != "CANCELLED"
            })
            hasMore = res.page < res.totalPages
            currentPage += 1
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func loadMessages(conversationId: String) async {
        isLoading = true
        messages = []
        currentConversationId = conversationId
        defer { isLoading = false }
        do {
            let res: MessagesResponse = try await APIClient.request(.listMessages(conversationId: conversationId, page: 1))
            messages = res.messages
            await markConversationRead(conversationId: conversationId)
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func markConversationRead(conversationId: String) async {
        do {
            let _: VoidResponse = try await APIClient.request(.markConversationRead(id: conversationId))
            socket.markConversationRead(conversationId)
            if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
                let conv = conversations[idx]
                conversations[idx] = Conversation(
                    id: conv.id, userId: conv.userId, artistId: conv.artistId, bookingId: conv.bookingId,
                    status: conv.status, lastMessageAt: conv.lastMessageAt,
                    lastMessageContent: conv.lastMessageContent,
                    createdAt: conv.createdAt, updatedAt: conv.updatedAt, unreadCount: 0,
                    messages: conv.messages, clientName: conv.clientName, clientAvatar: conv.clientAvatar
                )
            }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
        // Siempre refrescar el badge global, incluso si la conversación no estaba en lista
        // (cubre deep link directo sin lista cargada)
        await unreadStore.refreshUnread()
    }

    func sendMessage(conversationId: String, content: String) async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if socket.isConnected {
            socket.send(conversationId: conversationId, content: content)
            return
        }
        do {
            let wrapper: MessageWrapper = try await APIClient.request(
                .sendMessage(conversationId: conversationId, content: content)
            )
            messages.append(wrapper.message)
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func createOrOpenConversation(artistId: String) async -> Conversation? {
        do {
            let wrapper: ConversationWrapper = try await APIClient.request(.createConversation(artistId: artistId))
            return wrapper.conversation
        } catch {
            errorMessage = AppError(from: error).errorDescription
            return nil
        }
    }

    func unreadCount() async -> Int {
        do {
            let res: UnreadCountResponse = try await APIClient.request(.unreadCount)
            return res.unreadCount
        } catch { return 0 }
    }

    private func handleIncoming(_ msg: ChatMessage) {
        if currentConversationId == msg.conversationId,
           !messages.contains(where: { $0.id == msg.id }) {
            messages.append(msg)
        }
        if let idx = conversations.firstIndex(where: { $0.id == msg.conversationId }) {
            let conv = conversations[idx]
            let myId = AuthManager.shared.currentUser?.id ?? ""
            let unread = (conv.unreadCount ?? 0) + (msg.senderId == myId ? 0 : 1)
            conversations[idx] = Conversation(
                id: conv.id, userId: conv.userId, artistId: conv.artistId, bookingId: conv.bookingId,
                status: conv.status, lastMessageAt: msg.createdAt, lastMessageContent: msg.content,
                createdAt: conv.createdAt, updatedAt: conv.updatedAt, unreadCount: unread,
                messages: conv.messages, clientName: conv.clientName, clientAvatar: conv.clientAvatar
            )
        } else {
            // Conversación nueva (no está en la lista cargada) — refrescar inbox
            Task { await loadConversations() }
        }
    }
}
