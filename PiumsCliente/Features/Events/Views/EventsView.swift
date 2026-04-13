// EventsView.swift
import SwiftUI

struct EventsView: View {
    @State private var viewModel = EventsViewModel()
    @State private var showCreate = false
    @State private var selectedEvent: EventSummary?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                LoadingView()
            } else if viewModel.events.isEmpty {
                EmptyStateView(
                    systemImage: "ticket.fill",
                    title: "Sin eventos",
                    description: "Todavía no has creado eventos."
                )
            } else {
                List {
                    ForEach(viewModel.events) { event in
                        EventRow(event: event)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedEvent = event }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.loadEvents() }
            }
        }
        .navigationTitle("Eventos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await viewModel.loadEvents() }
        .sheet(isPresented: $showCreate) {
            EventFormView(onSave: { name, date, location, notes, description in
                Task { await viewModel.createEvent(name: name, date: date, location: location, notes: notes, description: description) }
                showCreate = false
            })
        }
        .navigationDestination(item: $selectedEvent) {
            EventDetailView(event: $0, viewModel: viewModel)
        }
    }
}

private struct EventRow: View {
    let event: EventSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "ticket.fill").foregroundStyle(statusColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.bold())
                Text(event.eventDate ?? "Sin fecha")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let bookingsCount = event.bookings?.count, bookingsCount > 0 {
                    Text("\(bookingsCount) reserva(s)")
                        .font(.caption2)
                        .foregroundStyle(Color.piumsOrange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(statusDisplayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var statusColor: Color {
        switch event.status {
        case .active: return Color.piumsOrange
        case .cancelled: return .red
        case .draft: return .gray
        }
    }
    
    private var statusDisplayName: String {
        switch event.status {
        case .active: return "Activo"
        case .cancelled: return "Cancelado"
        case .draft: return "Borrador"
        }
    }
}

// MARK: - Event Detail

private struct EventDetailView: View {
    let event: EventSummary
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showAddBooking = false
    @State var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        guard let raw = event.eventDate else { return "Sin fecha" }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = iso.date(from: raw) ?? df.date(from: String(raw.prefix(10))) else { return raw }
        let out = DateFormatter(); out.dateFormat = "EEEE d 'de' MMMM, yyyy"; out.locale = Locale(identifier: "es_ES")
        return out.string(from: d).capitalized
    }

    private var totalCost: Int {
        (event.bookings ?? []).reduce(0) { $0 + $1.totalPrice }
    }

    private var statusColor: Color {
        switch event.status {
        case .active:    return .green
        case .draft:     return .orange
        case .cancelled: return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Hero: estado ────────────────────────────
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(statusColor.opacity(0.15)).frame(width: 72, height: 72)
                        Image(systemName: "ticket.fill").font(.system(size: 32)).foregroundStyle(statusColor)
                    }
                    VStack(spacing: 4) {
                        Text(event.name).font(.title2.bold()).multilineTextAlignment(.center)
                        HStack(spacing: 6) {
                            Circle().fill(statusColor).frame(width: 7, height: 7)
                            Text(event.status.rawValue.capitalized)
                                .font(.caption.weight(.semibold)).foregroundStyle(statusColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
                .background(statusColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)

                // ── Código del evento ───────────────────────
                VStack(spacing: 6) {
                    Text("CÓDIGO DEL EVENTO")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(1.2)
                    Text(event.code).font(.title3.bold().monospaced())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Color.piumsOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.piumsOrange.opacity(0.2)))
                .padding(.horizontal, 20)

                // ── Info del evento ─────────────────────────
                EventDetailCard(title: "Información del Evento") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        EventInfoCell(label: "FECHA") {
                            Text(formattedDate).font(.subheadline.bold()).lineLimit(3)
                        }
                        EventInfoCell(label: "UBICACIÓN") {
                            Text(event.location ?? "No especificada")
                                .font(.subheadline.bold()).lineLimit(2)
                        }
                        if let desc = event.description {
                            EventInfoCell(label: "DESCRIPCIÓN") {
                                Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                        }
                        if let notes = event.notes {
                            EventInfoCell(label: "NOTAS") {
                                Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                        }
                    }
                }

                // ── Reservas asociadas ──────────────────────
                let bookings = event.bookings ?? []
                EventDetailCard(title: "Reservas del Evento (\(bookings.count))") {
                    if bookings.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.plus").foregroundStyle(.secondary)
                            Text("Aún no hay reservas asociadas a este evento.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(bookings.enumerated()), id: \.1.id) { idx, eb in
                                if idx > 0 { Divider() }
                                EventBookingRow(booking: eb)
                            }
                            Divider().padding(.top, 8)
                            // Grand total
                            HStack {
                                Text("Total del Evento").font(.headline)
                                Spacer()
                                Text(totalCost.piumsFormatted)
                                    .font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                            }
                            .padding(.top, 10)
                        }
                    }
                    
                    // Botón agregar reserva
                    Button(action: { showAddBooking = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Agregar Reserva")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }

                // ── Acciones ────────────────────────────────
                EventDetailCard(title: "Acciones") {
                    VStack(spacing: 10) {
                        eventActionButton(icon: "pencil", label: "Editar evento", color: Color.piumsOrange) {
                            showEdit = true
                        }
                        eventActionButton(icon: "calendar.badge.plus", label: "Agregar al Calendario", color: .blue) {
                            addToCalendar()
                        }
                        eventActionButton(icon: "square.and.arrow.up", label: "Compartir evento", color: .teal) {
                            showShareSheet = true
                        }
                        Divider()
                        eventActionButton(icon: "trash", label: "Eliminar evento", color: .red) {
                            showDeleteConfirm = true
                        }
                    }
                }

                Color.clear.frame(height: 20)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Evento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .confirmationDialog("¿Eliminar este evento?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.deleteEvent(event) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showEdit) {
            EventFormView(event: event, onSave: { name, date, location, notes, description in
                Task { await viewModel.updateEvent(event, name: name, date: date, location: location, notes: notes, description: description) }
                showEdit = false
            })
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["\(event.name) — \(formattedDate)\nCódigo: \(event.code)"])
        }
        .sheet(isPresented: $showAddBooking) {
            NavigationStack {
                AddBookingToEventView(event: event)
            }
        }
    }

    private func addToCalendar() {
        guard let raw = event.eventDate else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = iso.date(from: raw) ?? df.date(from: String(raw.prefix(10))) else { return }
        let title = event.name
        let loc = event.location ?? ""
        let startStr = d.formatted(.iso8601.year().month().day())
            .replacingOccurrences(of: "-", with: "")
        let url = URL(string: "https://calendar.google.com/calendar/render?action=TEMPLATE&text=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)&dates=\(startStr)/\(startStr)&location=\(loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc)")!
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func eventActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
                }
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(color == .red ? .red : .primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EventBookingRow

private struct EventBookingRow: View {
    let booking: EventBooking

    private var statusColor: Color {
        switch booking.status {
        case .pending:   return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelledClient, .cancelledArtist, .rejected: return .red
        default:         return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Code / ID
            VStack(alignment: .leading, spacing: 3) {
                Text(booking.code ?? String(booking.id.prefix(8)))
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                Text(scheduledFormatted).font(.subheadline.bold()).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(booking.totalPrice.piumsFormatted)
                    .font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(booking.status.displayName)
                        .font(.caption2.weight(.semibold)).foregroundStyle(statusColor)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var scheduledFormatted: String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = iso.date(from: booking.scheduledDate) ??
              df.date(from: String(booking.scheduledDate.prefix(10))) else { return booking.scheduledDate }
        let out = DateFormatter(); out.dateFormat = "d MMM yyyy"; out.locale = Locale(identifier: "es_ES")
        return out.string(from: d)
    }
}

// MARK: - Reusable event detail card + cell

private struct EventDetailCard<Content: View>: View {
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

private struct EventInfoCell<Content: View>: View {
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

// ShareSheet bridge (reused from BookingDetailView module)
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Event Form

private struct EventFormView: View {
    var event: EventSummary? = nil
    var onSave: (String, Date?, String?, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date? = nil
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var descriptionText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") { TextField("Nombre del evento", text: $name) }
                Section("Fecha") {
                    DatePicker("Selecciona fecha", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                }
                Section("Ubicación") { TextField("Lugar", text: $location) }
                Section("Descripción") { TextField("Descripción", text: $descriptionText) }
                Section("Notas") { TextField("Notas", text: $notes) }
            }
            .navigationTitle(event == nil ? "Nuevo evento" : "Editar evento")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(name, date, location, notes, descriptionText)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onAppear {
            if let event {
                name = event.name
                location = event.location ?? ""
                notes = event.notes ?? ""
                descriptionText = event.description ?? ""
            }
        }
    }
}

// MARK: - AddBookingToEventView

private struct AddBookingToEventView: View {
    let event: EventSummary
    @State private var searchQuery = ""
    @State private var artists: [Artist] = []
    @State private var isLoading = false
    @State private var selectedArtist: Artist?
    @State private var showBookingFlow = false
    @Environment(\.dismiss) private var dismiss
    
    var filteredArtists: [Artist] {
        guard !searchQuery.isEmpty else { return artists }
        let q = searchQuery.lowercased()
        return artists.filter {
            $0.artistName.lowercased().contains(q) ||
            ($0.specialties ?? []).joined().lowercased().contains(q)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar artista...", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            
            Divider()
            
            // Artists list
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredArtists.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "person.3.fill",
                    title: searchQuery.isEmpty ? "Sin artistas" : "No se encontraron artistas",
                    description: searchQuery.isEmpty
                        ? "Carga la lista de artistas disponibles."
                        : "Intenta con otro término de búsqueda."
                )
                Spacer()
            } else {
                List(filteredArtists) { artist in
                    Button {
                        selectedArtist = artist
                        showBookingFlow = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.piumsOrange.opacity(0.15)).frame(width: 48, height: 48)
                                Text(String(artist.artistName.prefix(2)).uppercased())
                                    .font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artist.artistName).font(.subheadline.bold())
                                if let spec = artist.specialties?.first {
                                    Text(spec).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Seleccionar Artista")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .task { await loadArtists() }
        .sheet(isPresented: $showBookingFlow) {
            if let artist = selectedArtist {
                NavigationStack {
                    BookingFlowView(context: BookingFlowContext(
                        artist: artist,
                        location: event.location ?? "",
                        locationLat: nil,
                        locationLng: nil,
                        eventId: event.id
                    ))
                }
                .presentationDetents([.large])
            }
        }
    }
    
    private func loadArtists() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res: SearchArtistsResponse = try await APIClient.request(
                .searchArtists(q: nil, page: 1, limit: 50, specialty: nil, city: nil,
                               minPrice: nil, maxPrice: nil, minRating: nil,
                               isVerified: nil, sortBy: nil, sortOrder: nil)
            )
            artists = res.artists
        } catch {
            print("❌ Failed to load artists: \(error)")
        }
    }
}

#Preview { NavigationStack { EventsView() } }
