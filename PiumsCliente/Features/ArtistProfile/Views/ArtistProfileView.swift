// ArtistProfileView.swift
import SwiftUI
import CoreLocation

struct ArtistProfileView: View {
    let artist: Artist
    @State private var viewModel: ArtistProfileViewModel
    @State private var selectedService: ArtistService?
    @State private var showBooking = false
    @State private var favorites = FavoritesStore.shared
    @State private var showFavError = false
    @Environment(\.locationStore) private var locationStore

    init(artist: Artist) {
        self.artist = artist
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
                    StatCell(value: artist.isVerified ? "✓" : "—", label: "Verificado")
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

                Divider().padding(.horizontal)

                // Servicios
                VStack(alignment: .leading, spacing: 12) {
                    Text("Servicios")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.isLoadingServices {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else if viewModel.services.isEmpty {
                        Text("Sin servicios disponibles")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(viewModel.services) { service in
                            ServiceRowView(service: service, isSelected: selectedService?.id == service.id) {
                                selectedService = service
                            } onReserve: {
                                selectedService = service
                                showBooking = true
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)

                Divider().padding(.horizontal)

                // Reseñas
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reseñas")
                        .font(.headline)
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

                // Galería / Portfolio
                if !viewModel.portfolio.isEmpty {
                    Divider().padding(.horizontal)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Galería")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.portfolio) { item in
                                    AsyncImage(url: URL(string: item.url)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable()
                                                .scaledToFill()
                                                .frame(width: 140, height: 140)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        case .failure, .empty:
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.tertiarySystemGroupedBackground))
                                                .frame(width: 140, height: 140)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .foregroundStyle(.secondary)
                                                        .font(.title)
                                                )
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                Divider().padding(.horizontal)

                // Información de Contacto (= sidebar de la web adaptada a móvil)
                ContactInfoView(
                    instagram: viewModel.instagram,
                    website: viewModel.website
                ) {
                    if let first = viewModel.services.first { selectedService = first }
                    showBooking = true
                }

                Spacer().frame(height: 100)
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
        .task { await viewModel.loadAll() }
        .onChange(of: favorites.errorMessage) { _, msg in showFavError = msg != nil }
        .alert("No se pudo actualizar favoritos", isPresented: $showFavError) {
            Button("OK") { favorites.errorMessage = nil }
        } message: {
            Text(favorites.errorMessage ?? "")
        }
        // Botón flotante Contratar
        .overlay(alignment: .bottom) {
            VStack {
                PiumsButton(title: selectedService == nil ? "Selecciona un servicio" : "Contratar") {
                    if selectedService != nil { showBooking = true }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .disabled(selectedService == nil)
            }
            .background(.regularMaterial)
        }
        .sheet(isPresented: $showBooking) {
            if let service = selectedService {
                let coord = locationStore.coordinate
                let lat: Double? = coord.map { $0.latitude }
                let lng: Double? = coord.map { $0.longitude }
                NavigationStack {
                    BookingFlowView(context: BookingFlowContext(
                        artist: artist,
                        service: service,
                        location: locationStore.cityName,
                        locationLat: lat,
                        locationLng: lng
                    ))
                }
            }
        }
    }
}

// MARK: - Información de Contacto

private struct ContactInfoView: View {
    let instagram: String?
    let website: String?
    let onReserve: () -> Void

    var hasSocialLinks: Bool { instagram != nil || website != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Información de Contacto")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 10) {
                Button(action: onReserve) {
                    Text("Reservar Ahora")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                NavigationLink(destination: InboxView()) {
                    Text("Enviar Mensaje")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.piumsOrange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.piumsOrange, lineWidth: 1.5))
                }
            }
            .padding(.horizontal)

            if hasSocialLinks {
                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
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
            }
        }
        .padding(.vertical)
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
    let isSelected: Bool
    let onTap: () -> Void
    let onReserve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.name).font(.subheadline.bold())
                        if let desc = service.description {
                            Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Label("\(service.duration) min", systemImage: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(service.price.piumsFormatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.piumsOrange)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }
                }
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
        .padding(14)
        .background(isSelected ? Color.piumsOrange.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 1.5)
        )
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

#Preview {
    NavigationStack {
        ArtistProfileView(artist: .mock)
    }
}
