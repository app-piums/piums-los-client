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
                            BookingRowView(booking: booking,
                                          cachedArtistName: viewModel.artistCache[booking.artistId]?.name)
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
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
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
        .navigationDestination(item: $selectedBooking) { booking in
            BookingDetailView(booking: booking,
                              preloadedArtist: viewModel.artistCache[booking.artistId])
        }
        .navigationDestination(for: String.self) { bookingId in
            if let booking = viewModel.bookings.first(where: { $0.id == bookingId }) {
                BookingDetailView(booking: booking,
                                  preloadedArtist: viewModel.artistCache[booking.artistId])
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
    var cachedArtistName: String? = nil

    private var displayName: String {
        cachedArtistName ?? booking.resolvedArtistName ?? "—"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icono estado
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        // Título principal: nombre del artista
                        Text(displayName)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        // Subtítulo: nombre + código
                        HStack(spacing: 4) {
                            Text(displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let code = booking.code {
                                Text("·").font(.caption).foregroundStyle(.secondary)
                                Text(code)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if booking.totalPrice > 0 {
                            Text(booking.totalPrice.piumsFormatted)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.piumsOrange)
                        }
                        Text(shortDate)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(booking.status.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                    if let time = booking.scheduledTime {
                        HStack(spacing: 3) {
                            Image(systemName: "clock").font(.caption2)
                            Text(time)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    if let dur = booking.duration {
                        HStack(spacing: 3) {
                            Image(systemName: "timer").font(.caption2)
                            Text("\(dur) min")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // "5 abr" style
    private var shortDate: String {
        let raw = booking.scheduledDate
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) ?? df.date(from: String(raw.prefix(10))) else { return raw }
        let out = DateFormatter(); out.dateFormat = "d MMM"; out.locale = Locale(identifier: "es_ES")
        return out.string(from: date)
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
        case .unknown:          return .secondary
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
        case .unknown:          return "questionmark.circle"
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
                .background(isSelected ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
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
    @State private var showReschedule = false
    @Environment(\.dismiss) private var dismiss

    @State private var loadedArtistName: String?
    @State private var loadedArtistAvatar: String?
    @State private var loadedArtistSpecialty: String?
    @State private var loadedArtistVerified: Bool = false

    init(booking: Booking, preloadedArtist: BookingArtistInfo? = nil) {
        self.booking = booking
        // Prioridad: cache pre-cargado → campos del booking → nil
        _loadedArtistName      = State(initialValue: preloadedArtist?.name      ?? booking.resolvedArtistName)
        _loadedArtistAvatar    = State(initialValue: preloadedArtist?.avatar    ?? booking.resolvedArtistAvatar)
        _loadedArtistSpecialty = State(initialValue: preloadedArtist?.specialty ?? booking.artist?.specialties?.first)
        _loadedArtistVerified  = State(initialValue: preloadedArtist?.isVerified ?? booking.artist?.isVerified ?? false)
    }

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
        case .unknown:          return .secondary
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
        case .unknown:          return "questionmark.circle.fill"
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

                // ── Participantes ───────────────────────────
                let currentUser = AuthManager.shared.currentUser
                DetailCard(title: "Participantes") {
                    VStack(spacing: 12) {
                        ParticipantRow(
                            role: "Artista",
                            name: loadedArtistName ?? booking.resolvedArtistName ?? "Cargando…",
                            detail: loadedArtistSpecialty ?? booking.artist?.specialties?.first,
                            avatarURL: loadedArtistAvatar ?? booking.resolvedArtistAvatar,
                            isVerified: loadedArtistVerified,
                            icon: "music.microphone",
                            tint: Color.piumsOrange
                        )
                        Divider()
                        ParticipantRow(
                            role: "Cliente",
                            name: currentUser?.displayName ?? booking.resolvedClientName ?? "Tú",
                            detail: currentUser?.email ?? booking.client?.email,
                            avatarURL: currentUser?.avatarUrl ?? booking.resolvedClientAvatar,
                            isVerified: false,
                            icon: "person.circle",
                            tint: .blue
                        )
                    }
                }

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
                        if canReschedule {
                            Divider()
                            actionButton(icon: "calendar.badge.clock", label: "Cambiar fecha", color: .purple) {
                                showReschedule = true
                            }
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
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle(booking.code ?? "Detalle de Reserva")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadArtist() }
        .sheet(isPresented: $showReview) { ReviewView(booking: booking) }
        .sheet(isPresented: $showQueja)  { CreateQuejaView(booking: booking) }
        .sheet(isPresented: $showReschedule) {
            RescheduleBookingSheet(booking: booking)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showShareSheet) {
            if let code = booking.code {
                ShareSheet(items: ["Mi reserva \(code) — \(formattedDate)"])
            }
        }
    }

    // MARK: - Helpers

    private func loadArtist() async {
        // Si ya tenemos nombre (del cache o del booking) solo rellenamos avatar/specialty si faltan
        guard loadedArtistName == nil else { return }
        struct ArtistDTO: Decodable {
            let name: String?
            let nombre: String?
            let avatar: String?
            let specialties: [String]?
            let isVerified: Bool?
            struct Nested: Decodable {
                let name: String?
                let nombre: String?
                let avatar: String?
                let specialties: [String]?
                let isVerified: Bool?
                var resolvedName: String? { name ?? nombre }
            }
            // maneja: { "artist": {} }, { "data": {} }, { "user": {} }, o campos en raíz
            let artist: Nested?
            let data: Nested?
            let user: Nested?
            var resolvedName: String?      { artist?.resolvedName ?? data?.resolvedName ?? user?.resolvedName ?? name ?? nombre }
            var resolvedAvatar: String?    { artist?.avatar ?? data?.avatar ?? user?.avatar ?? avatar }
            var resolvedSpecialty: String? { (artist?.specialties ?? data?.specialties ?? user?.specialties ?? specialties)?.first }
            var resolvedVerified: Bool     { artist?.isVerified ?? data?.isVerified ?? user?.isVerified ?? isVerified ?? false }
        }
        if let dto: ArtistDTO = try? await APIClient.request(.getArtist(id: booking.artistId)) {
            print("🎨 loadArtist \(booking.artistId) — resolvedName: \(dto.resolvedName ?? "nil")")
            if let n = dto.resolvedName      { loadedArtistName = n }
            if let a = dto.resolvedAvatar    { loadedArtistAvatar = a }
            if let s = dto.resolvedSpecialty { loadedArtistSpecialty = s }
            if dto.resolvedName != nil       { loadedArtistVerified = dto.resolvedVerified }
        } else {
            print("❌ loadArtist \(booking.artistId) — fetch/decode falló")
        }
    }

    private var canOpenQueja: Bool {
        switch booking.status {
        case .completed, .cancelledArtist, .noShow, .rejected: return true
        default: return false
        }
    }

    private var canReschedule: Bool {
        switch booking.status {
        case .pending, .confirmed, .rescheduled: return true
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

// MARK: - ParticipantRow

private struct ParticipantRow: View {
    let role: String
    let name: String
    let detail: String?
    let avatarURL: String?
    let isVerified: Bool
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Group {
                if let url = avatarURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(role.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                HStack(spacing: 5) {
                    Text(name).font(.subheadline.bold())
                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.piumsOrange)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(tint)
            }
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(tint.opacity(0.15))
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
        }
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
        .background(Color(.tertiarySystemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mi Espacio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        .background(Color(.tertiarySystemGroupedBackground))
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

// MARK: - RescheduleBookingSheet

struct RescheduleBookingSheet: View {
    let booking: Booking
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date? = nil
    @State private var selectedSlot: TimeSlot? = nil
    @State private var reason = ""
    @State private var disabledDates: [Date] = []
    @State private var slots: [TimeSlot] = []
    @State private var isLoadingSlots = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @State private var displayMonth = Date()

    private let cal = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Reserva actual
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fecha actual").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: "calendar").foregroundStyle(Color.piumsOrange)
                            Text(booking.scheduledDate).font(.subheadline.bold())
                            if let t = booking.scheduledTime {
                                Text("·").foregroundStyle(.secondary)
                                Image(systemName: "clock").foregroundStyle(Color.piumsOrange)
                                Text(t).font(.subheadline.bold())
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Calendario
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nueva fecha").font(.headline)
                        calendarView
                    }

                    // Slots
                    if !slots.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Horario disponible").font(.headline)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 8) {
                                ForEach(slots) { s in
                                    Button { selectedSlot = s } label: {
                                        Text(s.time)
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selectedSlot?.time == s.time ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
                                            .foregroundStyle(selectedSlot?.time == s.time ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else if isLoadingSlots {
                        ProgressView("Cargando horarios…").frame(maxWidth: .infinity)
                    } else if selectedDate != nil {
                        Text("No hay horarios disponibles para este día.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    // Motivo (opcional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Motivo del cambio (opcional)").font(.subheadline.weight(.medium))
                        TextEditor(text: $reason)
                            .frame(height: 70)
                            .padding(10)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Group {
                                    if reason.isEmpty {
                                        Text("Ej. Cambio de planes, evento adelantado…")
                                            .foregroundStyle(Color(.placeholderText))
                                            .padding(.leading, 14).padding(.top, 18)
                                            .allowsHitTesting(false)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    }
                                }
                            )
                    }

                    if let err = errorMessage {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    // Confirmar
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(didSucceed ? "¡Cambio solicitado!" : "Confirmar cambio de fecha")
                        }
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(canConfirm ? Color.piumsOrange : Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canConfirm)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Cambiar fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.piumsOrange)
                }
            }
            .task { await loadCalendar() }
        }
    }

    // MARK: - Calendar view (inline)

    private var calendarView: some View {
        VStack(spacing: 10) {
            HStack {
                Text(monthLabel).font(.headline.bold())
                Spacer()
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").foregroundStyle(Color.piumsOrange) }
                Button { changeMonth(1)  } label: { Image(systemName: "chevron.right").foregroundStyle(Color.piumsOrange) }
            }
            HStack(spacing: 0) {
                ForEach(["L","M","X","J","V","S","D"], id: \.self) {
                    Text($0).font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(calendarDays, id: \.self) { day in
                    let isOff = disabledDates.contains { cal.isDate($0, inSameDayAs: day) }
                    let isPast = day < cal.startOfDay(for: Date())
                    let isCurrent = cal.component(.month, from: day) == cal.component(.month, from: displayMonth)
                    let isSel = selectedDate.map { cal.isDate(day, inSameDayAs: $0) } ?? false
                    Button {
                        guard !isOff && !isPast && isCurrent else { return }
                        selectedDate = day; selectedSlot = nil
                        Task { await loadSlots(for: day) }
                    } label: {
                        ZStack {
                            if isSel      { Circle().fill(Color.piumsOrange) }
                            else if isOff { Circle().fill(Color.red.opacity(0.08)) }
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 13, weight: isSel ? .bold : .regular))
                                .foregroundStyle(isSel ? .white : isOff ? Color.red.opacity(0.5) : isPast || !isCurrent ? Color(.systemGray4) : .primary)
                        }
                        .frame(height: 34)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOff || isPast || !isCurrent)
                }
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "es_ES")
        return f.string(from: displayMonth).capitalized
    }

    private func changeMonth(_ d: Int) {
        if let n = cal.date(byAdding: .month, value: d, to: displayMonth) { withAnimation { displayMonth = n } }
    }

    private var calendarDays: [Date] {
        guard let start = cal.date(from: cal.dateComponents([.year,.month], from: displayMonth)),
              let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let wd = cal.component(.weekday, from: start); let off = (wd-2+7)%7
        return (-off..<(range.count + (7-(range.count+off)%7)%7)).compactMap {
            cal.date(byAdding: .day, value: $0, to: start)
        }
    }

    // MARK: - Async

    private func loadCalendar() async {
        let yr = cal.component(.year, from: displayMonth)
        let mo = cal.component(.month, from: displayMonth)
        do {
            let res: ArtistCalendar = try await APIClient.request(
                .getArtistCalendar(artistId: booking.artistId, year: yr, month: mo))
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            disabledDates = (res.occupiedDates + res.blockedDates).compactMap { f.date(from: $0) }
        } catch {}
    }

    private func loadSlots(for date: Date) async {
        isLoadingSlots = true; slots = []
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        do {
            let res: TimeSlotsResponse = try await APIClient.request(
                .getAvailableSlots(artistId: booking.artistId, date: f.string(from: date)))
            slots = res.slots.filter { $0.available }
        } catch {}
        isLoadingSlots = false
    }

    private func submit() async {
        guard let date = selectedDate, let slot = selectedSlot else { return }
        isSubmitting = true; errorMessage = nil
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var payload: [String: Any] = [
            "scheduledDate": df.string(from: date),
            "scheduledTime": slot.time
        ]
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { payload["reason"] = trimmed }
        do {
            let _: VoidResponse = try await APIClient.request(.rescheduleBooking(id: booking.id, payload: payload))
            didSucceed = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
        isSubmitting = false
    }

    private var canConfirm: Bool { selectedDate != nil && selectedSlot != nil && !isSubmitting }
}
