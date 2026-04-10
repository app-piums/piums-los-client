// MyBookingsView.swift
import SwiftUI

struct MyBookingsView: View {
    @State private var viewModel = MyBookingsViewModel()
    @State private var selectedBooking: Booking?
    @State private var bookingToCancel: Booking?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.statusFilters, id: \.self) { status in
                        StatusFilterChip(
                            title: viewModel.statusLabel(status),
                            isSelected: viewModel.selectedStatus == status
                        ) {
                            Task { await viewModel.selectStatus(status) }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            Divider()

            // Contenido
            if viewModel.isLoading && viewModel.bookings.isEmpty {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.bookings.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.minus",
                    title: "Sin reservas",
                    description: "Aún no tienes reservas. ¡Encuentra un artista y haz tu primera reserva!"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let msg = viewModel.errorMessage {
                            ErrorBannerView(message: msg)
                                .padding(.horizontal)
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
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                        Color.clear.frame(height: 12)
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.loadInitial() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Mis Reservas")
        .task { await viewModel.loadInitial() }
        .navigationDestination(item: $selectedBooking) { BookingDetailView(booking: $0) }
        .confirmationDialog(
            "¿Cancelar esta reserva?",
            isPresented: Binding(get: { bookingToCancel != nil }, set: { if !$0 { bookingToCancel = nil } }),
            titleVisibility: .visible
        ) {
            Button("Sí, cancelar", role: .destructive) {
                if let id = bookingToCancel?.id {
                    Task { await viewModel.cancelBooking(id: id) }
                }
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

    var body: some View {
        List {
            Section {
                DetailRow(label: "Código",    value: booking.code ?? "—")
                DetailRow(label: "Estado",    value: booking.status.displayName)
                DetailRow(label: "Fecha",     value: booking.scheduledDate)
                DetailRow(label: "Hora",      value: booking.scheduledTime ?? "—")
                if let dur = booking.duration {
                    DetailRow(label: "Duración", value: "\(dur) min")
                }
                DetailRow(label: "Ubicación", value: booking.location ?? "—")
            } header: { Text("Detalles") }

            Section {
                DetailRow(label: "Total",     value: booking.totalPrice.piumsFormatted)
                DetailRow(label: "Pago",      value: booking.paymentStatus.rawValue.capitalized)
            } header: { Text("Pago") }

            if let notes = booking.notes, !notes.isEmpty {
                Section("Notas") {
                    Text(notes).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(booking.code ?? "Detalle")
        .navigationBarTitleDisplayMode(.inline)
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
