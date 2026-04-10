// ChatDetailView.swift — detalle de conversación
import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation
    @State private var viewModel = ChatViewModel()
    @State private var newMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { msg in
                        MessageBubble(message: msg, isOwn: msg.senderType == "user")
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    TextField("Escribe un mensaje...", text: $newMessage)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let text = newMessage
                            newMessage = ""
                            await viewModel.sendMessage(conversationId: conversation.id, content: text)
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(Color.piumsOrange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadMessages(conversationId: conversation.id) }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isOwn: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 60) }
            Text(message.content)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isOwn ? Color.piumsOrange : Color(.secondarySystemBackground))
                .foregroundStyle(isOwn ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isOwn { Spacer(minLength: 60) }
        }
    }
}

#Preview {
    NavigationStack { ChatDetailView(conversation: Conversation(id: "1", userId: "u1", artistId: "a1", bookingId: nil, status: "ACTIVE", lastMessageAt: nil, createdAt: "", updatedAt: "", unreadCount: 0, messages: [])) }
}
