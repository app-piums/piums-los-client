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
                VStack(spacing: 0) {
                    if ChatSocketManager.shared.typingConversationId == conversation.id {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
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
                }
                .background(.bar)
                .animation(.easeInOut(duration: 0.2), value: ChatSocketManager.shared.typingConversationId)
            }
        }
        .background {
            let symbols = ["music.note","camera","film","party.popper","headphones","paintpalette","sparkles","figure.dance"]
            let tileSize: CGFloat = 80
            GeometryReader { geo in
                let cols = max(1, Int(geo.size.width / tileSize) + 2)
                let rows = max(1, Int(geo.size.height / tileSize) + 2)
                ForEach(0..<(rows * cols), id: \.self) { i in
                    let row = i / cols
                    let col = i % cols
                    Image(systemName: symbols[(row * cols + col) % symbols.count])
                        .font(.system(size: 22, weight: .ultraLight))
                        .foregroundStyle(Color.primary.opacity(0.06))
                        .rotationEffect(.degrees(-15))
                        .position(
                            x: CGFloat(col) * tileSize + (row % 2 == 0 ? 0 : tileSize / 2) + tileSize / 2,
                            y: CGFloat(row) * tileSize + tileSize / 2
                        )
                }
            }
            .ignoresSafeArea()
        }
        .navigationTitle(conversation.otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: newMessage) { _, text in
            guard !text.isEmpty else { return }
            viewModel.onInputChange(conversationId: conversation.id)
        }
        .task {
            ChatSocketManager.shared.joinConversation(conversation.id)
            await viewModel.loadMessages(conversationId: conversation.id)
        }
        .onDisappear {
            ChatSocketManager.shared.leaveConversation(conversation.id)
        }
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .offset(y: phase == i ? -4 : 0)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
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
        let iso = ISO8601DateFormatter()
        let raw = message.createdAt
        let date = iso.date(from: raw)
            ?? {
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return iso.date(from: raw)
            }()
        guard let date else { return String(raw.prefix(5)) }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
            conversation: Conversation(id: "1", userId: "u1", artistId: "a1", bookingId: nil,
                                       status: "ACTIVE", lastMessageAt: nil, lastMessageContent: nil,
                                       createdAt: "", updatedAt: "", unreadCount: 0, messages: [],
                                       clientName: "Carlos Méndez", clientAvatar: nil),
            viewModel: ChatViewModel()
        )
    }
}
