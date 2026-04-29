// NotificationsView.swift
import SwiftUI

// Destino de navegación extraído de una notificación
private enum NotifDestination: Identifiable, Hashable {
    case booking(id: String)
    case artist(id: String)
    case inbox

    var id: String {
        switch self {
        case .booking(let id): return "booking-\(id)"
        case .artist(let id):  return "artist-\(id)"
        case .inbox:           return "inbox"
        }
    }
}

private extension PiumsNotification {
    var destination: NotifDestination? {
        if let bid = data?.bookingId, !bid.isEmpty { return .booking(id: bid) }
        if type == "NEW_MESSAGE"                   { return .inbox }
        if let aid = data?.artistId,  !aid.isEmpty { return .artist(id: aid) }
        return nil
    }
}

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()
    @State private var navDestination: NotifDestination?

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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !notification.isRead {
                                    Task { await viewModel.markAsRead(id: notification.id) }
                                }
                                if let dest = notification.destination {
                                    navDestination = dest
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
        .navigationDestination(item: $navDestination) { dest in
            switch dest {
            case .booking(let id):
                DeepLinkBookingView(bookingId: id)
            case .artist(let id):
                DeepLinkArtistView(artistId: id)
            case .inbox:
                InboxView()
            }
        }
        .task { await viewModel.loadInitial() }
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

            if notification.destination != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color(.systemGray3))
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(notification.isRead ? Color(.tertiarySystemGroupedBackground) : Color.piumsOrange.opacity(0.05))
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

// MARK: - DeepLinkArtistView

struct DeepLinkArtistView: View {
    let artistId: String
    @State private var artist: Artist?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let artist {
                ArtistProfileView(artist: artist)
            } else {
                EmptyStateView(
                    systemImage: "person.slash",
                    title: "Artista no encontrado",
                    description: errorMessage ?? "No pudimos cargar este perfil.",
                    actionTitle: "Reintentar"
                ) { Task { await load() } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let res: ArtistDetailResponse = try await APIClient.request(.getArtist(id: artistId))
            artist = res.artist
            if artist == nil { errorMessage = "Perfil no disponible" }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
        isLoading = false
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
    @State private var unreadStore = ChatRealtimeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            PiumsSegmentedPicker(
                tabs: InboxTab.allCases,
                selected: $selected,
                label: \.rawValue,
                icon: \.systemImage,
                badge: { tab in
                    tab == .messages ? unreadStore.unreadCount : 0
                }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
            Divider()

            Group {
                switch selected {
                case .messages: ChatInboxView()
                case .quejas:   QuejasView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .navigationTitle("Mensajes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { unreadStore.startIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .chatUnreadNeedsRefresh)) { _ in
            Task { await unreadStore.refreshUnread() }
        }
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
