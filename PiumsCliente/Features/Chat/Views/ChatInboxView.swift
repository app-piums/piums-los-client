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
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill")
                    .foregroundStyle(statusColor)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Artista")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let bookingId = conversation.bookingId {
                    Text("Reserva: \(bookingId.prefix(8))...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.status.capitalized)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            if let unread = conversation.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.piumsOrange))
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusColor: Color {
        switch conversation.status.uppercased() {
        case "ACTIVE":  return Color.piumsOrange
        case "PENDING": return .blue
        case "CLOSED":  return .secondary
        default:        return .secondary
        }
    }

    private var relativeDate: String {
        guard let dateStr = conversation.lastMessageAt,
              let date = ISO8601DateFormatter().date(from: dateStr) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview { NavigationStack { ChatInboxView() } }
