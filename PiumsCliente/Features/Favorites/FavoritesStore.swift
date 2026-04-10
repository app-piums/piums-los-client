// FavoritesStore.swift — favoritos en local (no hay endpoint backend visible)
import Foundation

struct FavoriteArtist: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
    let city: String?
    let avatar: String?
    let rating: Double?
    let savedAt: String

    var avatarUrl: String? { avatar }

    static func == (lhs: FavoriteArtist, rhs: FavoriteArtist) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@Observable
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()
    private init() { load() }

    // Nota: no hay endpoint backend visible; usamos UserDefaults por ahora.
    private let maxFavorites = 100
    private var storageKey: String {
        if let id = AuthManager.shared.currentUser?.id { return "piums:favorites:\(id)" }
        return "piums:favorites:guest"
    }

    var favorites: [FavoriteArtist] = []

    func isFavorite(_ id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    func toggle(artist: Artist) {
        if let idx = favorites.firstIndex(where: { $0.id == artist.id }) {
            favorites.remove(at: idx)
        } else {
            let fav = FavoriteArtist(
                id: artist.id,
                name: artist.artistName,
                category: artist.specialties?.first,
                city: artist.city,
                avatar: artist.avatarUrl,
                rating: artist.rating,
                savedAt: ISO8601DateFormatter().string(from: Date())
            )
            favorites.insert(fav, at: 0)
            favorites = Array(favorites.prefix(maxFavorites))
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteArtist].self, from: data)
        else { return }
        favorites = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
