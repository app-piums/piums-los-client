// NotificationsView.swift
import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.notifications.isEmpty {
                EmptyStateView(
                    systemImage: "bell.slash",
                    title: "No se pudieron cargar",
                    description: error,
                    actionTitle: "Reintentar"
                ) { Task { await viewModel.loadInitial() } }
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(
                    systemImage: "bell.slash",
                    title: "Sin notificaciones",
                    description: "Aquí aparecerán tus alertas de reservas, pagos y más."
                )
            } else {
                List {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRowView(notification: notification)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                if !notification.isRead {
                                    Task { await viewModel.markAsRead(id: notification.id) }
                                }
                            }
                            .task { await viewModel.loadMoreIfNeeded(current: notification) }
                    }
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.loadInitial() }
            }
        }
        .navigationTitle("Notificaciones")
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Marcar todas leídas") {
                        Task { await viewModel.markAllRead() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.piumsOrange)
                }
            }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.loadInitial() }
    }
}

// MARK: - NotificationRowView

struct NotificationRowView: View {
    let notification: PiumsNotification

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Ícono
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline.bold())
                    Spacer()
                    if !notification.isRead {
                        Circle()
                            .fill(Color.piumsOrange)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(notification.createdAt.prefix(10))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(notification.isRead ? Color(.secondarySystemBackground) : Color.piumsOrange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(notification.isRead ? Color.clear : Color.piumsOrange.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch notification.type {
        case "BOOKING_CONFIRMED":   return "checkmark.circle.fill"
        case "BOOKING_CANCELLED":   return "xmark.circle.fill"
        case "PAYMENT_COMPLETED":   return "creditcard.fill"
        case "NEW_REVIEW":          return "star.fill"
        case "NEW_MESSAGE":         return "message.fill"
        default:                    return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case "BOOKING_CONFIRMED":   return .green
        case "BOOKING_CANCELLED":   return .red
        case "PAYMENT_COMPLETED":   return .blue
        case "NEW_REVIEW":          return .yellow
        case "NEW_MESSAGE":         return .piumsOrange
        default:                    return .secondary
        }
    }
}

#Preview {
    NavigationStack { NotificationsView() }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - InboxView — Mensajes · Quejas en un solo tab
// ══════════════════════════════════════════════════════════════════════

enum InboxTab: String, CaseIterable {
    case messages = "Mensajes"
    case quejas   = "Quejas"
    
    var systemImage: String {
        switch self {
        case .messages: return "message.fill"
        case .quejas:   return "exclamationmark.bubble.fill"
        }
    }
}

struct InboxView: View {
    @State private var selected: InboxTab = .messages
    @State private var unreadCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            PiumsSegmentedPicker(
                tabs: InboxTab.allCases,
                selected: $selected,
                label: \.rawValue,
                icon: \.systemImage,
                badge: { tab in
                    tab == .messages ? unreadCount : 0
                }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
            Divider()

            Group {
                switch selected {
                case .messages: MessagesPlaceholderView()
                case .quejas:   QuejasView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

private struct MessagesPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "message.fill",
            title: "Mensajes",
            description: "El chat en tiempo real con artistas estará disponible próximamente."
        )
    }
}
