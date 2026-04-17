// FavoritesStore.swift — favoritos desde backend
import Foundation

@Observable
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()
    private init() {}

    var favorites: [FavoriteRecord] = []
    var artistsById: [String: Artist] = [:]
    var isLoading = false
    var errorMessage: String?

    var favoriteArtists: [Artist] {
        favorites.compactMap { artistsById[$0.entityId] }
    }

    func loadFavorites() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var allFavorites: [FavoriteRecord] = []
            var page = 1
            var totalPages = 1
            repeat {
                let res: FavoritesResponse = try await APIClient.request(
                    .listFavorites(page: page, entityType: "ARTIST")
                )
                allFavorites.append(contentsOf: res.data)
                totalPages = res.totalPages
                page += 1
            } while page <= totalPages
            favorites = allFavorites
            await loadArtistsForFavorites()
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func isFavorite(_ artistId: String) -> Bool {
        favorites.contains { $0.entityId == artistId }
    }

    func toggle(artist: Artist) async {
        do {
            let check: FavoriteCheckResponse = try await APIClient.request(
                .checkFavorite(entityType: "ARTIST", entityId: artist.id)
            )
            if check.isFavorite, let favId = check.favoriteId {
                let _: VoidResponse = try await APIClient.request(.deleteFavorite(id: favId))
                favorites.removeAll { $0.id == favId }
                artistsById.removeValue(forKey: artist.id)
            } else {
                let rec: FavoriteRecord = try await APIClient.request(
                    .addFavorite(entityType: "ARTIST", entityId: artist.id, notes: nil)
                )
                favorites.insert(rec, at: 0)
                artistsById[artist.id] = artist
            }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func loadArtistsForFavorites() async {
        let ids = favorites.map { $0.entityId }
        await withTaskGroup(of: (String, Artist?).self) { group in
            for id in ids {
                group.addTask {
                    do {
                        let artist: Artist = try await APIClient.request(.getArtist(id: id))
                        return (id, artist)
                    } catch { return (id, nil) }
                }
            }
            for await (id, artist) in group {
                if let artist { artistsById[id] = artist }
            }
        }
    }
}
