// FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    @State private var store = FavoritesStore.shared
    @State private var selectedArtist: Artist?

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                EmptyStateView(
                    systemImage: "heart.fill",
                    title: "Favoritos",
                    description: "Guarda artistas con el corazón en su perfil para verlos aquí."
                )
            } else {
                List {
                    ForEach(store.favorites) { fav in
                        FavoriteRow(favorite: fav)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                // Cargar detalle con stub mínimo
                                selectedArtist = Artist(
                                    id: fav.id,
                                    name: fav.name,
                                    bio: nil,
                                    city: fav.city,
                                    state: nil,
                                    country: nil,
                                    averageRating: fav.rating,
                                    totalReviews: 0,
                                    totalBookings: 0,
                                    hourlyRateMin: nil,
                                    hourlyRateMax: nil,
                                    mainServicePrice: nil,
                                    mainServiceName: nil,
                                    isVerified: false,
                                    isActive: true,
                                    isAvailable: true,
                                    servicesCount: 0,
                                    serviceIds: nil,
                                    serviceTitles: nil,
                                    specialties: fav.category.map { [$0] },
                                    createdAt: nil
                                )
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
    }
}

private struct FavoriteRow: View {
    let favorite: FavoriteArtist

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.piumsOrange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "heart.fill").foregroundStyle(Color.piumsOrange))

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.name)
                    .font(.subheadline.bold())
                Text("\(favorite.category ?? "Artista") · \(favorite.city ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rating = favorite.rating {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating)).font(.caption.bold())
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { NavigationStack { FavoritesView() } }
