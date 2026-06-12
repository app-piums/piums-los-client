// ArtistProfileView.swift
import SwiftUI
import CoreLocation
import AVKit
import SafariServices

struct ArtistProfileView: View {
    let artist: Artist
    // Contexto opcional del flujo "buscar por fecha" (calendario): preserva
    // fecha y ubicación elegidas al continuar hacia la reserva.
    var preselectedDate: Date? = nil
    var presetLocation: String? = nil
    var presetLat: Double? = nil
    var presetLng: Double? = nil
    @State private var viewModel: ArtistProfileViewModel
    @State private var bookingService: ArtistService?
    @State private var detailService: ArtistService?
    @State private var showWriteReview = false
    @State private var favorites = FavoritesStore.shared
    @State private var showFavError = false
    @Environment(\.locationStore) private var locationStore

    init(artist: Artist,
         preselectedDate: Date? = nil,
         presetLocation: String? = nil,
         presetLat: Double? = nil,
         presetLng: Double? = nil) {
        self.artist = artist
        self.preselectedDate = preselectedDate
        self.presetLocation = presetLocation
        self.presetLat = presetLat
        self.presetLng = presetLng
        _viewModel = State(initialValue: ArtistProfileViewModel(artist: artist))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                ArtistHeaderView(artist: artist, avatarURL: viewModel.avatarURL)

                // Stats rápidas
                HStack(spacing: 0) {
                    StatCell(value: String(format: "%.1f", artist.rating ?? 0), label: "Rating")
                    Divider().frame(height: 40)
                    StatCell(value: "\(artist.reviewsCount)", label: "Reseñas")
                    Divider().frame(height: 40)
                    VStack(spacing: 2) {
                        Image(systemName: artist.isVerified ? "checkmark.seal.fill" : "minus")
                            .font(.title3.bold())
                            .foregroundStyle(Color.piumsOrange)
                        Text("Verificado").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
                .background(Color(.tertiarySystemGroupedBackground))

                // Bio
                if let bio = artist.bio {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Acerca del artista")
                            .font(.headline)
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // Certificaciones
                if !viewModel.certifications.isEmpty {
                    Divider().padding(.horizontal)
                    CertificationsSectionView(certifications: viewModel.certifications)
                }

                Divider().padding(.horizontal)

                // Servicios
                VStack(alignment: .leading, spacing: 12) {
                    Text("Servicios")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.isLoadingServices {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else if viewModel.services.isEmpty {
                        VStack(spacing: 6) {
                            Text("Sin servicios disponibles")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let err = viewModel.errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ForEach(viewModel.services) { service in
                            ServiceRowView(
                                service: service,
                                dayOffer: viewModel.dayOffers[service.id],
                                onViewDetails: { detailService = service },
                                onReserve: { bookingService = service }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)

                // Portafolio
                if !viewModel.portfolio.isEmpty {
                    Divider().padding(.horizontal)
                    PortfolioSectionView(items: viewModel.portfolio)
                        .padding(.vertical)
                }

                Divider().padding(.horizontal)

                // Redes Sociales
                ContactInfoView(
                    instagram: viewModel.instagram,
                    website: viewModel.website
                )

                Divider().padding(.horizontal)

                // Reseñas — al final
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Reseñas").font(.headline)
                        Spacer()
                        Button {
                            showWriteReview = true
                        } label: {
                            Label("Escribir reseña", systemImage: "star.bubble")
                                .font(.caption.bold())
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }
                    .padding(.horizontal)

                    if viewModel.isLoadingReviews {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else if viewModel.reviews.isEmpty {
                        Text("Aún no hay reseñas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(viewModel.reviews) { review in
                            ReviewRowView(review: review)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)

                Spacer().frame(height: 30)
            }
        }
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle(artist.artistName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await favorites.toggle(artist: artist) }
                } label: {
                    Image(systemName: favorites.isFavorite(artist.id) ? "heart.fill" : "heart")
                        .foregroundStyle(Color.piumsOrange)
                }
            }
        }
        .refreshable { await viewModel.loadAll() }
        .task { await viewModel.loadAll() }
        .onChange(of: favorites.errorMessage) { _, msg in showFavError = msg != nil }
        .alert("No se pudo actualizar favoritos", isPresented: $showFavError) {
            Button("OK") { favorites.errorMessage = nil }
        } message: {
            Text(favorites.errorMessage ?? "")
        }
        .sheet(item: $bookingService) { service in
            let coord = locationStore.coordinate
            let lat: Double? = coord.map { $0.latitude }
            let lng: Double? = coord.map { $0.longitude }
            NavigationStack {
                BookingFlowView(context: BookingFlowContext(
                    artist: artist,
                    service: service,
                    selectedDate: preselectedDate,
                    location: presetLocation ?? locationStore.cityName,
                    locationLat: presetLat ?? lat,
                    locationLng: presetLng ?? lng
                ))
            }
        }
        .sheet(item: $detailService) { service in
            ServiceDetailSheet(service: service, artist: artist) {
                detailService = nil
                bookingService = service
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewSheet(artistId: artist.id, artistName: artist.artistName) {
                Task { await viewModel.loadReviews() }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }
}

// MARK: - Certificaciones

private struct CertificationsSectionView: View {
    let certifications: [Certification]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Certificaciones")
                .font(.headline)
                .padding(.horizontal)

            ForEach(certifications) { cert in
                HStack(spacing: 12) {
                    Image(systemName: "rosette")
                        .font(.title3)
                        .foregroundStyle(Color.piumsOrange)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cert.name)
                            .font(.subheadline.bold())
                        if let issuer = cert.issuer {
                            HStack(spacing: 4) {
                                Text(issuer).font(.caption).foregroundStyle(.secondary)
                                if let year = cert.issueYear {
                                    Text("· \(year)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Spacer()
                    if let urlStr = cert.certificateUrl, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Información de Contacto

private struct ContactInfoView: View {
    let instagram: String?
    let website: String?

    var hasSocialLinks: Bool { instagram != nil || website != nil }

    var body: some View {
        guard hasSocialLinks else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                Text("Redes Sociales")
                    .font(.headline)
                    .padding(.horizontal)

                HStack(spacing: 14) {
                    if let ig = instagram {
                        Link(destination: URL(string: ig.hasPrefix("http") ? ig : "https://instagram.com/\(ig.trimmingCharacters(in: .init(charactersIn: "@")))") ?? URL(string: "https://instagram.com")!) {
                            Label("Instagram", systemImage: "camera")
                                .font(.subheadline)
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }
                    if let wb = website {
                        Link(destination: URL(string: wb.hasPrefix("http") ? wb : "https://\(wb)") ?? URL(string: "https://piums.io")!) {
                            Label("Sitio web", systemImage: "globe")
                                .font(.subheadline)
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        )
    }
}

// MARK: - Sub-views

private struct ArtistHeaderView: View {
    let artist: Artist
    var avatarURL: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Group {
                let url = avatarURL ?? artist.avatarUrl
                if let url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { $0.resizable().scaledToFill() } placeholder: { placeholder }
                } else {
                    placeholder
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(artist.artistName).font(.title2.bold())
                    if artist.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.piumsOrange)
                    }
                }
                Text(artist.specialties?.first ?? "Artista")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let city = artist.city {
                    Label(city, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private var placeholder: some View {
        ZStack {
            Color.piumsOrange.opacity(0.15)
            Image(systemName: "person.crop.circle")
                .font(.largeTitle)
                .foregroundStyle(Color.piumsOrange)
        }
    }
}

private struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).foregroundStyle(Color.piumsOrange)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ServiceRowView: View {
    let service: ArtistService
    var dayOffer: ServiceDayOffer? = nil
    let onViewDetails: () -> Void
    let onReserve: () -> Void

    private var priceLabel: String {
        service.price.piumsFormatted
    }

    private var pricingTypeLabel: String? {
        switch service.pricingType {
        case "FIXED":   return "Precio fijo"
        case "HOURLY":  return "Por hora"
        case "PACKAGE": return "Paquete"
        default:        return nil
        }
    }

    private var durationLabel: String? {
        let mins = service.duration
        guard mins > 0 else { return nil }
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name).font(.subheadline.bold())
                    if let desc = service.description {
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if durationLabel != nil || pricingTypeLabel != nil {
                        HStack(spacing: 10) {
                            if let dur = durationLabel {
                                Label(dur, systemImage: "clock")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if let type = pricingTypeLabel {
                                if durationLabel != nil {
                                    Text("·").foregroundStyle(.secondary).font(.caption)
                                }
                                Text(type).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(priceLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                    if let offer = dayOffer {
                        Text(offer.badgeLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onViewDetails) {
                    Text("Ver detalles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.piumsOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.piumsOrange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.piumsOrange.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: onReserve) {
                    Text("Reservar")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReviewRowView: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StarRatingView(rating: Double(review.rating))
                Spacer()
                Text(review.createdAt.prefix(10))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let comment = review.comment {
                Text(comment).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Review creation response (backend puede envolver en { review: {...} })

private struct CreateReviewResponse: Decodable {
    let review: Review?
    let id: String?
}

// MARK: - WriteReviewSheet

private struct WriteReviewSheet: View {
    let artistId: String
    let artistName: String
    let onSubmitted: () -> Void

    @State private var rating = 0
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var isLoadingBookings = true
    @State private var completedBookings: [Booking] = []
    @State private var selectedBookingId: String? = nil
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @Environment(\.dismiss) private var dismiss

    private let labels = ["", "Malo", "Regular", "Bueno", "Muy bueno", "Excelente"]

    private var canSubmit: Bool { rating > 0 && selectedBookingId != nil && !isSubmitting }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(.systemGray4)).frame(width: 36, height: 4).padding(.top, 14)

            if isLoadingBookings {
                ProgressView("Cargando reservas…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 60)
            } else if completedBookings.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(.systemGray3))
                    Text("Sin reservas completadas")
                        .font(.headline)
                    Text("Solo puedes dejar una reseña después de completar una reserva con este artista.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button("Cerrar") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Escribir reseña").font(.title2.bold())
                            Text(artistName).font(.subheadline).foregroundStyle(.secondary)
                        }

                        // Selector de reserva (si hay más de una)
                        if completedBookings.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reserva a reseñar").font(.subheadline.weight(.medium))
                                ForEach(completedBookings) { booking in
                                    let isSelected = selectedBookingId == booking.id
                                    Button {
                                        selectedBookingId = booking.id
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isSelected ? Color.piumsOrange : Color(.systemGray3))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(booking.resolvedArtistName ?? artistName)
                                                    .font(.subheadline.bold())
                                                Text(String(booking.scheduledDate.prefix(10)))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if let code = booking.code {
                                                Text(code).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(12)
                                        .background(isSelected ? Color.piumsOrange.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Estrellas
                        VStack(spacing: 6) {
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundStyle(star <= rating ? Color.piumsOrange : Color(.systemGray3))
                                        .onTapGesture { withAnimation(.easeInOut(duration: 0.1)) { rating = star } }
                                }
                            }
                            if rating > 0 {
                                Text(labels[rating]).font(.caption.bold()).foregroundStyle(Color.piumsOrange)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Comentario
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Comentario (opcional)").font(.subheadline.weight(.medium))
                            TextEditor(text: $comment)
                                .frame(height: 90)
                                .padding(10)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    Group {
                                        if comment.isEmpty {
                                            Text("Cuéntanos tu experiencia…")
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

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isSubmitting { ProgressView().tint(.white) }
                                Text(didSucceed ? "¡Reseña enviada!" : "Enviar reseña")
                            }
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(canSubmit ? Color.piumsOrange : Color(.systemGray4))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSubmit)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .task { await loadCompletedBookings() }
    }

    private func loadCompletedBookings() async {
        isLoadingBookings = true
        do {
            let res: BookingsResponse = try await APIClient.request(.listMyBookings(status: "COMPLETED", paymentStatus: nil, page: 1))
            completedBookings = res.allBookings.filter { $0.artistId == artistId }
            selectedBookingId = completedBookings.first?.id
        } catch {
            completedBookings = []
        }
        isLoadingBookings = false
    }

    private func submit() async {
        guard let bookingId = selectedBookingId else { return }
        isSubmitting = true
        errorMessage = nil
        var payload: [String: Any] = ["artistId": artistId, "bookingId": bookingId, "rating": rating]
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { payload["comment"] = trimmed }
        do {
            let _: CreateReviewResponse = try await APIClient.request(.createReview(payload: payload))
            didSucceed = true
            onSubmitted()
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
        isSubmitting = false
    }
}

// MARK: - ServiceDetailSheet

private struct ServiceDetailSheet: View {
    let service: ArtistService
    let artist: Artist
    let onReserve: () -> Void
    @State private var showDetails = true
    @Environment(\.dismiss) private var dismiss

    private var pricingTypeLabel: String? {
        switch service.pricingType {
        case "FIXED":   return "Precio fijo"
        case "HOURLY":  return "Por hora"
        case "PACKAGE": return "Paquete"
        default:        return nil
        }
    }

    private var durationLabel: String? {
        let mins = service.duration
        guard mins > 0 else { return nil }
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Cabecera servicio ─────────────────────────
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.piumsOrange.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "music.note")
                            .font(.title3).foregroundStyle(Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(service.name).font(.headline)
                        if let desc = service.description, !desc.isEmpty {
                            Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer()
                    Text(service.price.piumsFormatted)
                        .font(.headline).foregroundStyle(Color.piumsOrange)
                }
                .padding(16)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(16)

                // ── Toggle detalles ───────────────────────────
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showDetails.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showDetails ? "Ocultar detalles" : "Ver detalles")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.piumsOrange)
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.piumsOrange)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if showDetails {
                    Divider().padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 16) {
                        // Duración + tipo precio
                        if durationLabel != nil || pricingTypeLabel != nil {
                            HStack(spacing: 10) {
                                if let dur = durationLabel {
                                    Label(dur, systemImage: "clock")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                if let type = pricingTypeLabel {
                                    if durationLabel != nil {
                                        Text("·").foregroundStyle(.secondary)
                                    }
                                    Text(type).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Qué incluye
                        if let included = service.whatIsIncluded, !included.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Qué incluye")
                                    .font(.subheadline.weight(.semibold))
                                ForEach(included, id: \.self) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.piumsOrange)
                                            .font(.subheadline)
                                        Text(item)
                                            .font(.subheadline).foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider().padding(.horizontal, 16)

                // ── Fila artista ──────────────────────────────
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: artist.avatarUrl ?? "")) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill").foregroundStyle(.secondary)
                    }
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.artistName).font(.subheadline.weight(.semibold))
                        if let spec = artist.specialties?.first {
                            Text(spec).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Ver perfil").font(.caption.weight(.medium)).foregroundStyle(Color.piumsOrange)
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.piumsOrange)
                    }
                    .onTapGesture { dismiss() }
                }
                .padding(16)

                // ── Reservar ──────────────────────────────────
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onReserve() }
                } label: {
                    Text("Reservar este servicio")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Portafolio section

private struct PortfolioSectionView: View {
    let items: [PortfolioItem]
    @State private var selectedImage: PortfolioItem?
    @State private var videoUrl: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Portafolio")
                    .font(.headline)
                Text("\(items.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.piumsOrange))
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        PortfolioThumbnail(item: item)
                            .onTapGesture {
                                if item.isVideo {
                                    guard let vid = item.youtubeId else { return }
                                    videoUrl = URL(string: "https://m.youtube.com/watch?v=\(vid)")
                                } else {
                                    selectedImage = item
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: Binding(get: { videoUrl != nil }, set: { if !$0 { videoUrl = nil } })) {
            if let url = videoUrl {
                SafariVideoView(url: url)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(item: $selectedImage) { item in
            ImageGalleryView(item: item, items: items.filter { !$0.isVideo })
        }
    }
}

// SFSafariViewController en sheet — motor completo de Safari, sin Error 153,
// el usuario permanece dentro de la app.
private struct SafariVideoView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = false
        cfg.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: cfg)
        vc.preferredBarTintColor = .black
        vc.preferredControlTintColor = UIColor(named: "piumsOrange") ?? .systemOrange
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// Miniatura individual — imagen o video
private struct PortfolioThumbnail: View {
    let item: PortfolioItem

    private var thumbnailUrl: URL? {
        if item.isVideo {
            // Prioridad: thumbnailUrl del backend → thumbnail de YouTube por ID
            if let t = item.thumbnailUrl, let url = URL(string: t) { return url }
            return item.youtubeThumbnailUrl
        }
        return URL(string: item.resolvedImageUrl)
    }

    var body: some View {
        ZStack {
            AsyncImage(url: thumbnailUrl) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Color(.tertiarySystemGroupedBackground)
                        .overlay(Image(systemName: item.isVideo ? "play.rectangle.fill" : "photo")
                            .foregroundStyle(.secondary).font(.title2))
                }
            }

            if item.isVideo {
                Color.black.opacity(0.25)
                ZStack {
                    Circle().fill(Color.black.opacity(0.55)).frame(width: 40, height: 40)
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                }
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
    }
}


// MARK: - Fullscreen image gallery

private struct ImageGalleryView: View {
    let item: PortfolioItem
    let items: [PortfolioItem]   // solo imágenes
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    init(item: PortfolioItem, items: [PortfolioItem]) {
        self.item = item
        self.items = items
        self._currentIndex = State(initialValue: items.firstIndex(where: { $0.id == item.id }) ?? 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.1.id) { idx, it in
                    AsyncImage(url: URL(string: it.resolvedImageUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .scaleEffect(idx == currentIndex ? scale : 1)
                                .offset(idx == currentIndex ? offset : .zero)
                                .gesture(zoomDrag)
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: currentIndex) { _, _ in scale = 1; offset = .zero }

            // Barra superior
            HStack {
                if items.count > 1 {
                    Text("\(currentIndex + 1) / \(items.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
        }
        .statusBarHidden()
    }

    private var zoomDrag: some Gesture {
        MagnificationGesture()
            .onChanged { scale = max(1, $0) }
            .onEnded { _ in withAnimation { if scale < 1.2 { scale = 1; offset = .zero } } }
            .simultaneously(with:
                DragGesture()
                    .onChanged { if scale > 1 { offset = $0.translation } }
                    .onEnded { _ in withAnimation { if scale <= 1 { offset = .zero } } }
            )
    }
}

#Preview {
    NavigationStack {
        ArtistProfileView(artist: .mock)
    }
}
