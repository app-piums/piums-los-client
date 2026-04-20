// ChatDetailView.swift — detalle de conversación
import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation
    @Bindable var viewModel: ChatViewModel
    @State private var newMessage = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg, isOwn: msg.senderId == AuthManager.shared.currentUser?.id)
                                .id(msg.id)
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollProxy = proxy }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    TextField("Escribe un mensaje...", text: $newMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    Button {
                        Task {
                            let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            newMessage = ""
                            await viewModel.sendMessage(conversationId: conversation.id, content: text)
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.piumsOrange)
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ChatSocketManager.shared.joinConversation(conversation.id)
            await viewModel.loadMessages(conversationId: conversation.id)
        }
        .onDisappear {
            ChatSocketManager.shared.leaveConversation(conversation.id)
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isOwn: Bool

    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
            HStack {
                if isOwn { Spacer(minLength: 60) }
                Text(message.content)
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isOwn ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
                    .foregroundStyle(isOwn ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                if !isOwn { Spacer(minLength: 60) }
            }
            Text(formattedTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: message.createdAt) else { return "" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
            conversation: Conversation(id: "1", userId: "u1", artistId: "a1", bookingId: nil, status: "ACTIVE", lastMessageAt: nil, createdAt: "", updatedAt: "", unreadCount: 0, messages: []),
            viewModel: ChatViewModel()
        )
    }
}
