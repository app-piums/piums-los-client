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
            conversations.append(contentsOf: res.conversations)
            hasMore = res.page < res.totalPages
            currentPage += 1
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func loadMessages(conversationId: String) async {
        isLoading = true
        messages = []
        defer { isLoading = false }
        do {
            let res: MessagesResponse = try await APIClient.request(.listMessages(conversationId: conversationId, page: 1))
            messages = res.messages
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func sendMessage(conversationId: String, content: String) async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            let wrapper: MessageWrapper = try await APIClient.request(
                .sendMessage(conversationId: conversationId, content: content)
            )
            messages.append(wrapper.message)
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func unreadCount() async -> Int {
        do {
            let res: UnreadCountResponse = try await APIClient.request(.unreadCount)
            return res.unreadCount
        } catch { return 0 }
    }
}
