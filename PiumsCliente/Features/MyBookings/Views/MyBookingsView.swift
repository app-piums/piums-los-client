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
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed

    private var formattedDate: String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let raw = booking.scheduledDate
        let date = iso.date(from: raw) ?? df.date(from: String(raw.prefix(10)))
        guard let d = date else { return raw }
        let out = DateFormatter(); out.dateFormat = "EEEE d 'de' MMMM, yyyy"; out.locale = Locale(identifier: "es_ES")
        return out.string(from: d).capitalized
    }

    private var formattedTime: String {
        guard let t = booking.scheduledTime else { return "" }
        let parts = t.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return t }
        let h = parts[0]; let m = parts[1]
        return String(format: "%d:%02d %@", h > 12 ? h-12 : (h == 0 ? 12 : h), m, h >= 12 ? "PM" : "AM")
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
        case .confirmed:        return "checkmark.circle.fill"
        case .paymentPending:   return "creditcard"
        case .paymentCompleted: return "creditcard.fill"
        case .inProgress:       return "play.circle.fill"
        case .completed:        return "checkmark.seal.fill"
        case .cancelledClient, .cancelledArtist: return "xmark.circle.fill"
        case .rejected:         return "hand.raised.fill"
        case .noShow:           return "person.slash.fill"
        case .rescheduled:      return "arrow.clockwise.circle.fill"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Hero: estado ────────────────────────────
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(statusColor.opacity(0.15)).frame(width: 72, height: 72)
                        Image(systemName: statusIcon).font(.system(size: 36)).foregroundStyle(statusColor)
                    }
                    VStack(spacing: 4) {
                        Text(booking.status.displayName).font(.title2.bold())
                        if let code = booking.code {
                            Text(code).font(.caption.weight(.semibold).monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(statusColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)

                // ── Código de reserva ───────────────────────
                if let code = booking.code {
                    VStack(spacing: 6) {
                        Text("CÓDIGO DE RESERVA")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(1.2)
                        Text(code).font(.title3.bold().monospaced())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color.piumsOrange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.piumsOrange.opacity(0.2)))
                    .padding(.horizontal, 20)
                }

                // ── Información del evento ──────────────────
                DetailCard(title: "Información del Evento") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        BookingInfoCell(label: "FECHA") {
                            Text(formattedDate).font(.subheadline.bold()).lineLimit(2)
                            if !formattedTime.isEmpty {
                                Text(formattedTime).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        BookingInfoCell(label: "UBICACIÓN") {
                            Text(booking.location ?? "No especificada").font(.subheadline.bold()).lineLimit(2)
                            Text("Modalidad Presencial").font(.caption).foregroundStyle(.secondary)
                        }
                        BookingInfoCell(label: "ESTADO RESERVA") {
                            HStack(spacing: 5) {
                                Circle().fill(statusColor).frame(width: 7, height: 7)
                                Text(booking.status.displayName).font(.caption.weight(.semibold))
                                    .foregroundStyle(statusColor)
                            }
                        }
                        BookingInfoCell(label: "ESTADO PAGO") {
                            HStack(spacing: 5) {
                                let pc: Color = booking.paymentStatus == .completed ? .green :
                                               booking.paymentStatus == .failed ? .red : .orange
                                Circle().fill(pc).frame(width: 7, height: 7)
                                Text(booking.paymentStatus.rawValue.capitalized)
                                    .font(.caption.weight(.semibold)).foregroundStyle(pc)
                            }
                        }
                    }
                }

                // ── Resumen de pago ─────────────────────────
                DetailCard(title: "Resumen de Pago") {
                    VStack(spacing: 12) {
                        payRow(label: "Total del servicio", value: booking.totalPrice.piumsFormatted, bold: false)
                        Divider()
                        payRow(label: "Total", value: booking.totalPrice.piumsFormatted, bold: true)
                    }
                }

                // ── Notas ───────────────────────────────────
                if let notes = booking.notes, !notes.isEmpty {
                    DetailCard(title: "Notas") {
                        Text(notes).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                // ── Acciones ────────────────────────────────
                DetailCard(title: "Acciones") {
                    VStack(spacing: 10) {
                        // Agregar a calendario (iOS nativo)
                        actionButton(icon: "calendar.badge.plus", label: "Agregar al Calendario", color: .blue) {
                            addToCalendar()
                        }
                        // Compartir
                        actionButton(icon: "square.and.arrow.up", label: "Compartir reserva", color: Color.piumsOrange) {
                            showShareSheet = true
                        }
                        if booking.status == .completed {
                            Divider()
                            actionButton(icon: "star.bubble", label: "Dejar reseña", color: .yellow) {
                                showReview = true
                            }
                        }
                        if canOpenQueja {
                            Divider()
                            actionButton(icon: "exclamationmark.bubble", label: "Abrir queja", color: .red) {
                                showQueja = true
                            }
                        }
                    }
                }

                Color.clear.frame(height: 20)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(booking.code ?? "Detalle de Reserva")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(isPresented: $showReview) { ReviewView(booking: booking) }
        .sheet(isPresented: $showQueja)  { CreateQuejaView(booking: booking) }
        .sheet(isPresented: $showShareSheet) {
            if let code = booking.code {
                ShareSheet(items: ["Mi reserva \(code) — \(formattedDate)"])
            }
        }
    }

    // MARK: - Helpers

    private var canOpenQueja: Bool {
        switch booking.status {
        case .completed, .cancelledArtist, .noShow, .rejected: return true
        default: return false
        }
    }

    private func addToCalendar() {
        guard let dateStr = booking.scheduledDate as String?,
              let isoDate = ISO8601DateFormatter().date(from: dateStr) ??
              DateFormatter().apply({ $0.dateFormat = "yyyy-MM-dd" }).date(from: String(dateStr.prefix(10))) else { return }
        let h = booking.scheduledTime.flatMap { t -> Int? in
            Int(t.split(separator:":").first ?? "") } ?? 10
        var comps = Calendar.current.dateComponents([.year,.month,.day], from: isoDate)
        comps.hour = h; comps.minute = 0
        guard let start = Calendar.current.date(from: comps) else { return }
        let end = start.addingTimeInterval(Double((booking.duration ?? 60) * 60))
        let startStr = start.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        let endStr = end.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        let title = "Reserva Piums — \(booking.code ?? booking.id)"
        let loc = booking.location ?? ""
        let url = URL(string: "https://calendar.google.com/calendar/render?action=TEMPLATE&text=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)&dates=\(startStr)/\(endStr)&location=\(loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc)")!
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func payRow(label: String, value: String, bold: Bool) -> some View {
        HStack {
            Text(label).font(bold ? .headline : .subheadline).foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value).font(bold ? .title3.bold() : .subheadline.weight(.medium))
                .foregroundStyle(bold ? Color.piumsOrange : .primary)
        }
    }

    @ViewBuilder
    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
                }
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable detail card + cell

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }
}

private struct BookingInfoCell<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ShareSheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// DateFormatter helper
private extension DateFormatter {
    @discardableResult
    func apply(_ block: (DateFormatter) -> Void) -> DateFormatter { block(self); return self }
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
