// ChatInboxView.swift — lista de conversaciones
import SwiftUI

struct ChatInboxView: View {
    @State private var viewModel = ChatViewModel()
    @State private var selectedConversation: Conversation?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                LoadingView()
            } else if viewModel.conversations.isEmpty {
                EmptyStateView(
                    systemImage: "message.fill",
                    title: "Sin mensajes",
                    description: "Aún no tienes conversaciones con artistas."
                )
            } else {
                List {
                    ForEach(viewModel.conversations) { conv in
                        ConversationRow(conversation: conv)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedConversation = conv }
                            .task {
                                if conv.id == viewModel.conversations.last?.id {
                                    await viewModel.loadNextConversations()
                                }
                            }
                    }
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.loadConversations() }
            }
        }
        .navigationDestination(item: $selectedConversation) {
            ChatDetailView(conversation: $0, viewModel: viewModel)
        }
        .task { await viewModel.loadConversations() }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.piumsOrange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.fill").foregroundStyle(Color.piumsOrange))

            VStack(alignment: .leading, spacing: 4) {
                Text("Conversación")
                    .font(.subheadline.bold())
                Text(conversation.lastMessageAt?.prefix(10) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let unread = conversation.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.piumsOrange))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { NavigationStack { ChatInboxView() } }
