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

// MARK: - Lightweight DTO for avatar (resilient to shape changes in /api/artists/:id)

private struct ArtistAvatarResponse: Decodable {
    let avatar: String?
    let avatarUrl: String?
    let name: String?
    let nombre: String?
    let coverUrl: String?
    let coverPhoto: String?
    let instagram: String?
    let website: String?

    struct Inner: Decodable {
        let avatar: String?
        let avatarUrl: String?
        let name: String?
        let nombre: String?
        let coverUrl: String?
        let coverPhoto: String?
        let instagram: String?
        let website: String?
        var resolvedAvatar: String? { avatar ?? avatarUrl }
        var resolvedName: String?  { name ?? nombre }
        var resolvedCoverInner: String? { coverUrl ?? coverPhoto }
    }
    // maneja: { "artist": {} }, { "data": {} }, { "user": {} }, o campos en raíz
    let artist: Inner?
    let data: Inner?
    let user: Inner?

    var resolved: String?     { artist?.resolvedAvatar ?? data?.resolvedAvatar ?? user?.resolvedAvatar ?? avatar ?? avatarUrl }
    var resolvedName: String? { artist?.resolvedName   ?? data?.resolvedName   ?? user?.resolvedName   ?? name ?? nombre }
    var resolvedCover: String?     { artist?.resolvedCoverInner ?? data?.resolvedCoverInner ?? user?.resolvedCoverInner ?? coverUrl ?? coverPhoto }
    var resolvedInstagram: String? { artist?.instagram  ?? data?.instagram  ?? user?.instagram  ?? instagram }
    var resolvedWebsite: String?   { artist?.website    ?? data?.website    ?? user?.website    ?? website }
}

// MARK: - ViewModel

@Observable
@MainActor
final class ArtistProfileViewModel {
    var artist: Artist
    var avatarURL: String?
    var coverURL: String?
    var instagram: String?
    var website: String?
    var services: [ArtistService] = []
    var reviews: [Review] = []
    var portfolio: [PortfolioItem] = []
    var isLoadingServices = false
    var isLoadingReviews = false
    var isLoadingPortfolio = false
    var errorMessage: String?

    init(artist: Artist) {
        self.artist = artist
        self.coverURL = artist.coverUrl
        self.instagram = artist.instagram
        self.website = artist.website
    }

    func loadAll() async {
        async let s: () = loadServices()
        async let r: () = loadReviews()
        async let p: () = loadPortfolio()
        async let d: () = loadArtistDetail()
        _ = await (s, r, p, d)
    }

    func loadArtistDetail() async {
        do {
            let dto: ArtistAvatarResponse = try await APIClient.request(.getArtist(id: artist.id))
            if let url = dto.resolved          { avatarURL = url }
            if let url = dto.resolvedCover     { coverURL = url }
            if let ig  = dto.resolvedInstagram { instagram = ig }
            if let wb  = dto.resolvedWebsite   { website = wb }
        } catch {}
    }

    func loadServices() async {
        isLoadingServices = true
        defer { isLoadingServices = false }
        do {
            let res: CatalogServicesResponse = try await APIClient.request(.listServices(artistId: artist.id))
            services = res.services.filter { $0.isActive }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func loadReviews() async {
        isLoadingReviews = true
        defer { isLoadingReviews = false }
        do {
            let res: ReviewsResponse = try await APIClient.request(.listReviews(artistId: artist.id, page: 1))
            reviews = res.allReviews
        } catch {
            errorMessage = AppError(from: error).errorDescription
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
