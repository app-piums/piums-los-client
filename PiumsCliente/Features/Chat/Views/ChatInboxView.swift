// ChatInboxView.swift — lista de conversaciones
import SwiftUI

struct ChatInboxView: View {
    @State private var viewModel = ChatViewModel()
    @State private var selectedConversation: Conversation?
    private let chatStore = ChatRealtimeStore.shared

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
        .safeAreaInset(edge: .bottom) {
            if let msg = viewModel.errorMessage {
                ErrorBannerView(message: msg)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { viewModel.errorMessage = nil }
            }
        }
        .animation(.spring(response: 0.35), value: viewModel.errorMessage)
        .navigationDestination(item: $selectedConversation) {
            ChatDetailView(conversation: $0, viewModel: viewModel)
        }
        .task {
            await viewModel.loadConversations()
            // Consume el deep link guardado al venir de una push con la app cerrada/background
            if let id = chatStore.pendingDeepLinkConversationId {
                chatStore.pendingDeepLinkConversationId = nil
                await openConversation(id: id)
            }
        }
        // Consume el deep link mientras la vista ya está activa
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { note in
            if let id = note.userInfo?["conversationId"] as? String {
                Task { await openConversation(id: id) }
            }
        }
    }

    // Busca la conversación en la lista cargada; si no está, la pide al backend.
    // Evita un fetch de red innecesario cuando la conversación ya está en memoria.
    private func openConversation(id: String) async {
        if let existing = viewModel.conversations.first(where: { $0.id == id }) {
            selectedConversation = existing
            return
        }
        do {
            let wrapper: ConversationWrapper = try await APIClient.request(.getConversation(id: id))
            selectedConversation = wrapper.conversation
        } catch {
            // Silently ignore — el usuario puede encontrar la conversación en la lista
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    private var participantName: String { conversation.otherParticipantName }
    private var avatarUrl: String? { conversation.otherParticipantAvatar }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                if let url = avatarUrl.flatMap(URL.init) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(statusColor)
                            .font(.system(size: 20))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(statusColor)
                        .font(.system(size: 20))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(participantName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let preview = conversation.lastMessageContent ?? conversation.messages?.last?.content {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(statusLabel)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
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

    private var statusLabel: String {
        switch conversation.status.uppercased() {
        case "ACTIVE":  return "Activo"
        case "PENDING": return "Pendiente"
        case "CLOSED":  return "Cerrado"
        default:        return conversation.status.capitalized
        }
    }

    private var relativeDate: String {
        guard let dateStr = conversation.lastMessageAt else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: dateStr) ?? {
            // fallback without fractional seconds
            let plain = ISO8601DateFormatter()
            return plain.date(from: dateStr)
        }()
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview { NavigationStack { ChatInboxView() } }
