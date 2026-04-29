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

    private var hasDoneInitialLoad = false
    private var isToggling = false

    var favoriteArtists: [Artist] {
        favorites.compactMap { artistsById[$0.entityId] }
    }

    func loadFavorites() async {
        isLoading = true
        errorMessage = nil
        hasDoneInitialLoad = true
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
        guard !isToggling else { return }
        isToggling = true
        defer { isToggling = false }

        // Cargar favoritos si aún no se han traído del backend
        if !hasDoneInitialLoad {
            await loadFavorites()
        }

        if let existing = favorites.first(where: { $0.entityId == artist.id }) {
            // Ya es favorito → quitar optimistamente
            favorites.removeAll { $0.id == existing.id }
            artistsById.removeValue(forKey: artist.id)
            do {
                let _: VoidResponse = try await APIClient.request(.deleteFavorite(id: existing.id))
            } catch {
                // Revertir si falla
                favorites.insert(existing, at: 0)
                artistsById[artist.id] = artist
                errorMessage = AppError(from: error).errorDescription
            }
        } else {
            // No es favorito → agregar optimistamente con registro temporal
            let tempId = UUID().uuidString
            let placeholder = FavoriteRecord(
                id: tempId, entityType: "ARTIST", entityId: artist.id,
                notes: nil, createdAt: "", deletedAt: nil
            )
            favorites.insert(placeholder, at: 0)
            artistsById[artist.id] = artist
            do {
                let resp: FavoriteAddResponse = try await APIClient.request(
                    .addFavorite(entityType: "ARTIST", entityId: artist.id, notes: nil)
                )
                if let idx = favorites.firstIndex(where: { $0.id == tempId }) {
                    favorites[idx] = resp.favorite
                }
            } catch {
                favorites.removeAll { $0.id == tempId }
                artistsById.removeValue(forKey: artist.id)
                errorMessage = AppError(from: error).errorDescription
            }
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
