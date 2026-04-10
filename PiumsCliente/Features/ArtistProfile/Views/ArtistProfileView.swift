// ArtistProfileView.swift
import SwiftUI

struct ArtistProfileView: View {
    let artist: Artist
    @State private var viewModel: ArtistProfileViewModel
    @State private var selectedService: ArtistService?
    @State private var showBooking = false

    init(artist: Artist) {
        self.artist = artist
        _viewModel = State(initialValue: ArtistProfileViewModel(artist: artist))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                ArtistHeaderView(artist: artist)

                // Stats rápidas
                HStack(spacing: 0) {
                    StatCell(value: String(format: "%.1f", artist.rating ?? 0), label: "Rating")
                    Divider().frame(height: 40)
                    StatCell(value: "\(artist.reviewsCount)", label: "Reseñas")
                    Divider().frame(height: 40)
                    StatCell(value: artist.isVerified ? "✓" : "—", label: "Verificado")
                }
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))

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
                                                .fill(Color(.secondarySystemBackground))
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

                // Espaciado para el botón flotante
                Spacer().frame(height: 100)
            }
        }
        .navigationTitle(artist.artistName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
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
                BookingFlowView(artist: artist, service: service)
            }
        }
    }
}

// MARK: - Sub-views

private struct ArtistHeaderView: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let url = artist.avatarUrl, let imageURL = URL(string: url) {
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

    var body: some View {
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
            .padding(14)
            .background(isSelected ? Color.piumsOrange.opacity(0.08) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ArtistProfileView(artist: .mock)
    }
}
