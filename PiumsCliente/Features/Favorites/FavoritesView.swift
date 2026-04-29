// FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    @State private var store = FavoritesStore.shared
    @State private var selectedArtist: Artist?

    var body: some View {
        Group {
            if store.isLoading && store.favoriteArtists.isEmpty {
                LoadingView()
            } else if store.favoriteArtists.isEmpty {
                EmptyStateView(
                    systemImage: "heart.fill",
                    title: "Favoritos",
                    description: "Guarda artistas con el corazón en su perfil para verlos aquí."
                )
            } else {
                List {
                    ForEach(store.favoriteArtists) { artist in
                        FavoriteArtistRow(artist: artist)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedArtist = artist }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await store.toggle(artist: artist) }
                                } label: {
                                    Label("Quitar", systemImage: "heart.slash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await store.loadFavorites() }
            }
        }
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
        .task { await store.loadFavorites() }
    }
}

private struct FavoriteArtistRow: View {
    let artist: Artist

    private var initials: String {
        artist.artistName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0) } }.joined().uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = artist.avatarUrl ?? artist.coverUrl, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.artistName)
                    .font(.subheadline.bold())
                Text("\(artist.specialties?.first ?? "Artista") · \(artist.city ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rating = artist.rating {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating)).font(.caption.bold())
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var placeholder: some View {
        ZStack {
            Color.piumsOrange.opacity(0.15)
            Text(initials).font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
        }
    }
}

#Preview { NavigationStack { FavoritesView() } }
