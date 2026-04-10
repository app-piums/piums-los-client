// DisputeDetailView.swift — detalle de queja + mensajería
import SwiftUI

struct DisputeDetailView: View {
    @State private var viewModel: DisputeDetailViewModel
    @FocusState private var messageFocused: Bool

    init(dispute: Dispute) {
        _viewModel = State(initialValue: DisputeDetailViewModel(dispute: dispute))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header tarjeta
                    headerCard
                        .padding()

                    Divider().padding(.horizontal)

                    // Resolución (si existe)
                    if let res = viewModel.dispute.resolution {
                        resolutionCard(res)
                            .padding()
                        Divider().padding(.horizontal)
                    }

                    // Descripción
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Descripción", systemImage: "doc.text")
                            .font(.headline)
                        Text(viewModel.dispute.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    Divider().padding(.horizontal)

                    // Mensajes
                    messagesSection

                    Color.clear.frame(height: 20)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollIndicators(.hidden)
            .refreshable { await viewModel.refresh() }
            .safeAreaInset(edge: .bottom) {
                // El input ocupa el safeAreaInset para que el scroll llegue justo hasta él
                if canSendMessage {
                    messageInput
                }
            }
        }
        .navigationTitle("Queja")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    // MARK: - Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(viewModel.dispute.type.replacingOccurrences(of: "_", with: " ").capitalized,
                      systemImage: "exclamationmark.bubble")
                    .font(.subheadline.bold())
                Spacer()
                StatusPill(status: viewModel.dispute.status)
            }

            Text(viewModel.dispute.subject)
                .font(.title3.bold())

            HStack(spacing: 16) {
                Label(viewModel.dispute.createdAt.shortDate, systemImage: "calendar")
                if let priority = viewModel.dispute.priority, priority == "HIGH" || priority == "URGENT" {
                    Label("Alta prioridad", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Resolution card

    private func resolutionCard(_ resolutionText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Resolución", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text(resolutionText)
                .font(.subheadline.bold())
            if let amount = viewModel.dispute.refundAmount, amount > 0 {
                Label("Reembolso: Q\(String(format: "%.2f", amount))", systemImage: "creditcard")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Messages

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mensajes", systemImage: "bubble.left.and.right")
                .font(.headline)
                .padding(.horizontal)

            if let messages = viewModel.dispute.messages, !messages.isEmpty {
                ForEach(messages) { msg in
                    MessageBubble(
                        message: msg,
                        isOwn: msg.senderId == AuthManager.shared.currentUser?.id
                    )
                    .padding(.horizontal)
                }
            } else {
                Text("Aún no hay mensajes en esta queja.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            if let msg = viewModel.errorMessage {
                ErrorBannerView(message: msg).padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Message input

    private var messageInput: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                TextField("Escribe un mensaje...", text: $viewModel.newMessage, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($messageFocused)

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    if viewModel.isSendingMessage {
                        ProgressView().frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(viewModel.newMessage.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? Color.secondary : Color.piumsOrange)
                            .clipShape(Circle())
                    }
                }
                .disabled(viewModel.newMessage.trimmingCharacters(in: .whitespaces).isEmpty
                          || viewModel.isSendingMessage)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var canSendMessage: Bool {
        switch viewModel.dispute.status {
        case .open, .inReview, .awaitingInfo, .escalated: return true
        case .resolved, .closed: return false
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: DisputeMessage
    let isOwn: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 60) }
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                if !isOwn {
                    let role = message.senderRole
                    Text(role == "admin" || role == "staff" ? "Soporte Piums" : "Tú")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                Text(message.message)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOwn ? Color.piumsOrange : Color(.secondarySystemBackground))
                    .foregroundStyle(isOwn ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message.createdAt.shortDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            if !isOwn { Spacer(minLength: 60) }
        }
    }
}

// MARK: - StatusPill (local)

private struct StatusPill: View {
    let status: DisputeStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    private var color: Color {
        switch status {
        case .open: return .orange
        case .inReview: return .blue
        case .awaitingInfo: return .yellow
        case .resolved: return .green
        case .closed: return .gray
        case .escalated: return .red
        }
    }
}

private extension String {
    var shortDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: self) ?? iso2.date(from: self) else { return self }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "es_GT")
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DisputeDetailView(dispute: Dispute(
            id: "d1", bookingId: "b1", reportedBy: "u1", reportedAgainst: "a1",
            type: "QUALITY", subject: "El artista llegó tarde 30 minutos",
            description: "Contraté un músico para las 15:00 y llegó a las 15:30 sin avisar.",
            status: .inReview, priority: "HIGH",
            resolution: nil, refundAmount: nil,
            createdAt: "2026-04-09T09:00:00Z", updatedAt: "2026-04-09T11:00:00Z",
            messages: [
                DisputeMessage(id: "m1", disputeId: "d1", senderId: "u1", senderRole: "cliente",
                               message: "Por favor resuelvan esto pronto.", createdAt: "2026-04-09T10:00:00Z"),
                DisputeMessage(id: "m2", disputeId: "d1", senderId: "staff1", senderRole: "staff",
                               message: "Hemos notificado al artista.", createdAt: "2026-04-09T11:00:00Z")
            ]
        ))
    }
}
