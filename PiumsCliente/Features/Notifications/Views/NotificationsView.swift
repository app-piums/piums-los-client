// NotificationsView.swift
import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingView()
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
                    }
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
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
                Text(notification.body)
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
