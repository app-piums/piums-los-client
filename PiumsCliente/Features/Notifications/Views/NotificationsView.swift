// NotificationsView.swift
import SwiftUI

// Destino de navegación extraído de una notificación
private enum NotifDestination: Identifiable, Hashable {
    case booking(id: String)
    case artist(id: String)
    case dispute(id: String)
    case inbox
    case coupons

    var id: String {
        switch self {
        case .booking(let id):  return "booking-\(id)"
        case .artist(let id):   return "artist-\(id)"
        case .dispute(let id):  return "dispute-\(id)"
        case .inbox:            return "inbox"
        case .coupons:          return "coupons"
        }
    }
}

private extension PiumsNotification {
    var destination: NotifDestination? {
        let t = type.uppercased()
        // Cupones/descuentos → pestaña Cupones en Mi Espacio
        if t == "COUPON_SENT" || t == "COUPON_EXPIRING" || t == "DISCOUNT" { return .coupons }
        // Disputas (acepta mayúsculas y minúsculas del backend)
        if let did = data?.disputeId, !did.isEmpty,
           t == "DISPUTE_OPENED" || t == "DISPUTE_RESOLVED" || t == "DISPUTE_MESSAGE" {
            return .dispute(id: did)
        }
        // Reserva directa o mediante bookingId
        if let bid = data?.bookingId, !bid.isEmpty { return .booking(id: bid) }
        // Mensajes
        if t == "NEW_MESSAGE" || t == "SUPPORT_REPLY" { return .inbox }
        // Artista
        if let aid = data?.artistId, !aid.isEmpty { return .artist(id: aid) }
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
            case .dispute(let id):
                DeepLinkDisputeView(disputeId: id)
            case .inbox:
                InboxView()
            case .coupons:
                CouponsView()
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
        switch notification.type.uppercased() {
        // Reserva
        case "BOOKING_CONFIRMED":                    return "checkmark.circle.fill"
        case "BOOKING_CANCELLED":                    return "xmark.circle.fill"
        case "BOOKING_IN_PROGRESS":                  return "play.circle.fill"
        case "BOOKING_DELIVERED":                    return "shippingbox.fill"
        case "BOOKING_COMPLETED", "AUTO_COMPLETE":   return "checkmark.seal.fill"
        case "BOOKING_NO_SHOW":                      return "person.slash.fill"
        case "DELIVERY_PROBLEM_REPORTED":            return "exclamationmark.triangle.fill"
        // Reagendamiento
        case "RESCHEDULE_REQUESTED",
             "RESCHEDULE_REQUEST":                   return "calendar.badge.clock"
        case "RESCHEDULE_APPROVED":                  return "calendar.badge.checkmark"
        case "RESCHEDULE_REJECTED":                  return "calendar.badge.minus"
        // Pagos
        case "PAYMENT_COMPLETED", "ANTICIPO_PAID":   return "creditcard.fill"
        case "BALANCE_CHARGED", "COMMISSION":        return "banknote"
        case "PAYMENT_FAILED":                       return "creditcard.trianglebadge.exclamationmark"
        case "REFUND_ISSUED":                        return "arrow.uturn.left.circle.fill"
        // Disputas
        case "DISPUTE_OPENED":                       return "exclamationmark.triangle.fill"
        case "DISPUTE_RESOLVED":                     return "shield.checkered"
        // Cupones / descuentos
        case "COUPON_SENT":                          return "tag.fill"
        case "COUPON_EXPIRING":                      return "tag.badge.minus"
        case "DISCOUNT":                             return "percent"
        // Social
        case "NEW_REVIEW":                           return "star.fill"
        case "NEW_MESSAGE", "SUPPORT_REPLY":         return "message.fill"
        default:                                     return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type.uppercased() {
        case "BOOKING_CONFIRMED", "BOOKING_COMPLETED",
             "AUTO_COMPLETE", "BOOKING_DELIVERED":   return .green
        case "BOOKING_CANCELLED", "BOOKING_NO_SHOW",
             "RESCHEDULE_REJECTED", "PAYMENT_FAILED",
             "DISPUTE_OPENED",
             "DELIVERY_PROBLEM_REPORTED":            return .red
        case "BOOKING_IN_PROGRESS":                  return Color.piumsOrange
        case "RESCHEDULE_REQUESTED", "RESCHEDULE_REQUEST",
             "RESCHEDULE_APPROVED":                  return .purple
        case "PAYMENT_COMPLETED", "ANTICIPO_PAID",
             "BALANCE_CHARGED", "COMMISSION":        return .blue
        case "REFUND_ISSUED":                        return .teal
        case "DISPUTE_RESOLVED":                     return .teal
        case "COUPON_SENT", "DISCOUNT":              return .green
        case "COUPON_EXPIRING":                      return .orange
        case "NEW_REVIEW":                           return .yellow
        case "NEW_MESSAGE", "SUPPORT_REPLY":         return Color.piumsOrange
        default:                                     return .secondary
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

// MARK: - DeepLinkDisputeView

struct DeepLinkDisputeView: View {
    let disputeId: String
    @State private var dispute: Dispute?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let dispute {
                DisputeDetailView(dispute: dispute)
            } else {
                EmptyStateView(
                    systemImage: "exclamationmark.bubble.fill",
                    title: "Queja no encontrada",
                    description: errorMessage ?? "No pudimos cargar esta queja.",
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
            dispute = try await APIClient.request(.getDispute(id: disputeId))
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

