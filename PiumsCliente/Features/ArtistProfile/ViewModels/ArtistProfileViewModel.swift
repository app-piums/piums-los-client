// ArtistProfileViewModel.swift
import Foundation

@Observable
@MainActor
final class ArtistProfileViewModel {
    var artist: Artist
    var services: [ArtistService] = []
    var reviews: [Review] = []
    var isLoadingServices = false
    var isLoadingReviews = false
    var errorMessage: String?

    init(artist: Artist) {
        self.artist = artist
    }

    func loadAll() async {
        async let s: () = loadServices()
        async let r: () = loadReviews()
        _ = await (s, r)
    }

    func loadServices() async {
        isLoadingServices = true
        defer { isLoadingServices = false }
        do {
            let res: PaginatedResponse<ArtistService> = try await APIClient.request(.listServices(artistId: artist.id))
            services = res.data
        } catch {
            // Mock fallback
            services = ArtistService.mockList(artistId: artist.id)
        }
    }

    func loadReviews() async {
        isLoadingReviews = true
        defer { isLoadingReviews = false }
        do {
            let res: PaginatedResponse<Review> = try await APIClient.request(.listReviews(artistId: artist.id, page: 1))
            reviews = res.data
        } catch {
            reviews = Review.mockList(artistId: artist.id)
        }
    }
}

// MARK: - Mock extensions

extension ArtistService {
    static func mockList(artistId: String) -> [ArtistService] {
        [
            ArtistService(id: "s1", artistId: artistId, name: "Show 1 hora", description: "Presentación completa de 60 min.", price: 15000, currency: "GTQ", duration: 60, category: nil, isActive: true),
            ArtistService(id: "s2", artistId: artistId, name: "Show 30 min", description: "Mini presentación perfecta para eventos pequeños.", price: 9000, currency: "GTQ", duration: 30, category: nil, isActive: true)
        ]
    }
}

extension Review {
    static func mockList(artistId: String) -> [Review] {
        [
            Review(id: "r1", artistId: artistId, clientId: "c1", bookingId: "b1", rating: 5, comment: "Excelente presentación, todos quedaron encantados.", createdAt: "2026-03-15T10:00:00Z"),
            Review(id: "r2", artistId: artistId, clientId: "c2", bookingId: "b2", rating: 4, comment: "Muy buen artista, puntual y profesional.", createdAt: "2026-02-20T14:00:00Z")
        ]
    }
}
