// ArtistProfileViewModel.swift
import Foundation

// MARK: - Portfolio model

struct PortfolioItem: Codable, Identifiable {
    let id: String
    let artistId: String
    let url: String
    let type: String?        // "image" | "video"
    let title: String?
    let description: String?
    let createdAt: String?
}

struct PortfolioResponse: Codable {
    let portfolio: [PortfolioItem]?
    let items: [PortfolioItem]?
    var allItems: [PortfolioItem] { portfolio ?? items ?? [] }
}

// MARK: - ViewModel

@Observable
@MainActor
final class ArtistProfileViewModel {
    var artist: Artist
    var services: [ArtistService] = []
    var reviews: [Review] = []
    var portfolio: [PortfolioItem] = []
    var isLoadingServices = false
    var isLoadingReviews = false
    var isLoadingPortfolio = false
    var errorMessage: String?

    init(artist: Artist) { self.artist = artist }

    func loadAll() async {
        async let s: () = loadServices()
        async let r: () = loadReviews()
        async let p: () = loadPortfolio()
        _ = await (s, r, p)
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

    func loadPortfolio() async {
        isLoadingPortfolio = true
        defer { isLoadingPortfolio = false }
        do {
            let res: PortfolioResponse = try await APIClient.request(.getArtistPortfolio(id: artist.id))
            portfolio = res.allItems
        } catch { portfolio = [] }
    }
}
