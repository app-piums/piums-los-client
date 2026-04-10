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
            let res: CatalogServicesResponse = try await APIClient.request(.listServices(artistId: artist.id))
            services = res.services.filter { $0.isActive }
        } catch {
            services = ArtistService.mockList(artistId: artist.id)
        }
    }

    func loadReviews() async {
        isLoadingReviews = true
        defer { isLoadingReviews = false }
        do {
            let res: ReviewsResponse = try await APIClient.request(.listReviews(artistId: artist.id, page: 1))
            reviews = res.allReviews
        } catch {
            reviews = Review.mockList(artistId: artist.id)
        }
    }
}


