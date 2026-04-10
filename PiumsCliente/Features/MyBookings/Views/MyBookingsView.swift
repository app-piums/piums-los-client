// MyBookingsView.swift
import SwiftUI

struct MyBookingsView: View {
    @State private var viewModel = MyBookingsViewModel()
    @State private var selectedBooking: Booking?
    @State private var bookingToCancel: Booking?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.bookings.isEmpty {
                LoadingView()
            } else if viewModel.bookings.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.minus",
                    title: "Sin reservas",
                    description: "Aún no tienes reservas. ¡Encuentra un artista y haz tu primera reserva!"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let msg = viewModel.errorMessage {
                            ErrorBannerView(message: msg).padding(.horizontal)
                        }
                        ForEach(viewModel.bookings) { booking in
                            BookingRowView(booking: booking)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedBooking = booking }
                                .task { await viewModel.loadNextIfNeeded(item: booking) }
                                .swipeActions(edge: .trailing) {
                                    if booking.status == .pending || booking.status == .confirmed {
                                        Button(role: .destructive) {
                                            bookingToCancel = booking
                                        } label: {
                                            Label("Cancelar", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                        }
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                        }
                        Color.clear.frame(height: 12)
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.loadInitial() }
            }
        }
        // Barra de filtros pegada bajo la navbar — no interfiere con el ScrollView
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.statusFilters, id: \.self) { status in
                            StatusFilterChip(
                                title: viewModel.statusLabel(status),
                                isSelected: viewModel.selectedStatus == status
                            ) { Task { await viewModel.selectStatus(status) } }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                Divider()
            }
            .background(.bar)
        }
        .navigationTitle("Mis Reservas")
        .task { await viewModel.loadInitial() }
        .navigationDestination(item: $selectedBooking) { BookingDetailView(booking: $0) }
        .navigationDestination(for: String.self) { bookingId in
            if let booking = viewModel.bookings.first(where: { $0.id == bookingId }) {
                BookingDetailView(booking: booking)
            } else {
                DeepLinkBookingView(bookingId: bookingId)
            }
        }
        .confirmationDialog(
            "¿Cancelar esta reserva?",
            isPresented: Binding(get: { bookingToCancel != nil }, set: { if !$0 { bookingToCancel = nil } }),
            titleVisibility: .visible
        ) {
            Button("Sí, cancelar", role: .destructive) {
                if let id = bookingToCancel?.id { Task { await viewModel.cancelBooking(id: id) } }
                bookingToCancel = nil
            }
            Button("No", role: .cancel) { bookingToCancel = nil }
        }
    }
}

// MARK: - BookingRowView

struct BookingRowView: View {
    let booking: Booking

    var body: some View {
        HStack(spacing: 14) {
            // Icono estado
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let code = booking.code {
                        Text(code).font(.headline)
                    } else {
                        Text("Reserva").font(.headline)
                    }
                    Spacer()
                    Text(booking.totalPrice.piumsFormatted)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
                Text(booking.status.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(booking.scheduledDate)
                    if let time = booking.scheduledTime {
                        Text("·")
                        Image(systemName: "clock").font(.caption2)
                        Text(time)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusColor: Color {
        switch booking.status {
        case .pending:          return .orange
        case .confirmed:        return .blue
        case .paymentPending:   return .yellow
        case .paymentCompleted: return .teal
        case .inProgress:       return .piumsOrange
        case .completed:        return .green
        case .cancelledClient, .cancelledArtist, .rejected, .noShow: return .red
        case .rescheduled:      return .purple
        }
    }

    private var statusIcon: String {
        switch booking.status {
        case .pending:          return "clock"
        case .confirmed:        return "checkmark.circle"
        case .paymentPending, .paymentCompleted: return "creditcard"
        case .inProgress:       return "play.circle"
        case .completed:        return "checkmark.seal"
        case .cancelledClient, .cancelledArtist: return "xmark.circle"
        case .rejected:         return "hand.raised"
        case .noShow:           return "person.slash"
        case .rescheduled:      return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}

// MARK: - StatusFilterChip

private struct StatusFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? Color.piumsOrange : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - BookingDetailView

struct BookingDetailView: View {
    let booking: Booking
    @State private var showReview = false
    @State private var showQueja  = false

    var body: some View {
        List {
            // Estado visual
            Section {
                HStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: statusIcon).foregroundStyle(statusColor))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(booking.status.displayName)
                            .font(.headline)
                        if let code = booking.code {
                            Text(code).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Detalles") {
                DetailRow(label: "Fecha",     value: booking.scheduledDate)
                DetailRow(label: "Hora",      value: booking.scheduledTime ?? "—")
                if let dur = booking.duration {
                    DetailRow(label: "Duración", value: "\(dur) min")
                }
                DetailRow(label: "Ubicación", value: booking.location ?? "—")
            }

            Section("Pago") {
                DetailRow(label: "Total",  value: booking.totalPrice.piumsFormatted)
                DetailRow(label: "Estado", value: booking.paymentStatus.rawValue.capitalized)
            }

            if let notes = booking.notes, !notes.isEmpty {
                Section("Notas") {
                    Text(notes).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            // ── Acciones según estado ──────────────────────────
            if booking.status == .completed {
                Section {
                    Button {
                        showReview = true
                    } label: {
                        Label("Dejar reseña", systemImage: "star.bubble")
                            .foregroundStyle(Color.piumsOrange)
                    }
                }
            }

            if canOpenQueja {
                Section {
                    Button {
                        showQueja = true
                    } label: {
                        Label("Abrir queja", systemImage: "exclamationmark.bubble")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(booking.code ?? "Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showReview) {
            ReviewView(booking: booking)
        }
        .sheet(isPresented: $showQueja) {
            CreateQuejaView(booking: booking)
        }
    }

    private var canOpenQueja: Bool {
        switch booking.status {
        case .completed, .cancelledArtist, .noShow, .rejected: return true
        default: return false
        }
    }

    private var statusColor: Color {
        switch booking.status {
        case .pending:          return .orange
        case .confirmed:        return .blue
        case .paymentPending, .paymentCompleted: return .teal
        case .inProgress:       return Color.piumsOrange
        case .completed:        return .green
        case .cancelledClient, .cancelledArtist, .rejected, .noShow: return .red
        case .rescheduled:      return .purple
        }
    }

    private var statusIcon: String {
        switch booking.status {
        case .pending:          return "clock"
        case .confirmed:        return "checkmark.circle"
        case .paymentPending, .paymentCompleted: return "creditcard"
        case .inProgress:       return "play.circle"
        case .completed:        return "checkmark.seal"
        case .cancelledClient, .cancelledArtist: return "xmark.circle"
        case .rejected:         return "hand.raised"
        case .noShow:           return "person.slash"
        case .rescheduled:      return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack { MyBookingsView() }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - MySpaceView — Reservas · Eventos · Favoritos en un solo tab
// ══════════════════════════════════════════════════════════════════════

enum MySpaceTab: String, CaseIterable {
    case bookings  = "Reservas"
    case events    = "Eventos"
    case favorites = "Favoritos"

    var systemImage: String {
        switch self {
        case .bookings:  return "calendar"
        case .events:    return "ticket.fill"
        case .favorites: return "heart.fill"
        }
    }
}

struct MySpaceView: View {
    @State private var selected: MySpaceTab = .bookings

    var body: some View {
        VStack(spacing: 0) {
            PiumsSegmentedPicker(tabs: MySpaceTab.allCases,
                                 selected: $selected,
                                 label: \.rawValue,
                                 icon: \.systemImage)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            Divider()

            Group {
                switch selected {
                case .bookings:  MyBookingsView()
                case .events:    EventsView()
                case .favorites: FavoritesView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .navigationTitle("My Space")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

// Picker genérico reutilizable para MySpace e Inbox
struct PiumsSegmentedPicker<T: Hashable & CaseIterable>: View {
    let tabs: [T]
    @Binding var selected: T
    let label: (T) -> String
    let icon: (T) -> String
    var badge: ((T) -> Int)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon(tab)).font(.system(size: 12))
                        Text(label(tab)).font(.subheadline.weight(.medium))
                        if let b = badge?(tab), b > 0 {
                            Text("\(b)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        selected == tab
                                        ? Color.white.opacity(0.35)
                                        : Color.piumsOrange
                                    )
                                )
                        }
                    }
                    .foregroundStyle(selected == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected == tab ? Color.piumsOrange : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: selected)
            }
        }
        .padding(4)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

struct EventsContentView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "ticket.fill",
            title: "Eventos",
            description: "Próximamente podrás crear eventos y agrupar múltiples artistas para una misma ocasión."
        )
    }
}

struct FavoritesContentView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "heart.fill",
            title: "Favoritos",
            description: "Guarda artistas con el botón de corazón en su perfil para encontrarlos rápido aquí."
        )
    }
}
