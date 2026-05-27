// ArtistProfileViewModel.swift
import Foundation

// MARK: - Portfolio model

struct PortfolioItem: Codable, Identifiable {
    let id: String
    let artistId: String
    let url: String
    let thumbnailUrl: String?   // provisto por backend para items de video
    let imageUrl: String?       // alias alternativo que usan algunos endpoints
    let type: String?           // "image" | "video" | "audio"
    let title: String?
    let description: String?
    let createdAt: String?

    var resolvedImageUrl: String { imageUrl ?? url }
    var isVideo: Bool { type?.lowercased() == "video" }
    var youtubeId: String? {
        guard isVideo else { return nil }
        let pattern = #"(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([A-Za-z0-9_-]{11})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              let range = Range(match.range(at: 1), in: url)
        else { return nil }
        return String(url[range])
    }
    var youtubeEmbedUrl: URL? {
        guard let vid = youtubeId else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(vid)?autoplay=1&playsinline=1")
    }
    var youtubeThumbnailUrl: URL? {
        guard let vid = youtubeId else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(vid)/hqdefault.jpg")
    }
}

struct PortfolioResponse: Decodable {
    let allItems: [PortfolioItem]

    private enum CK: String, CodingKey { case portfolio, items, data }

    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CK.self) {
            if let s = try? c.decode([PortfolioItem].self, forKey: .portfolio) { allItems = s; return }
            if let d = try? c.decode([PortfolioItem].self, forKey: .data)      { allItems = d; return }
            if let i = try? c.decode([PortfolioItem].self, forKey: .items)     { allItems = i; return }
        }
        allItems = []
    }
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
        let certifications: [Certification]?
        var resolvedAvatar: String? { avatar ?? avatarUrl }
        var resolvedName: String?  { name ?? nombre }
        var resolvedCoverInner: String? { coverUrl ?? coverPhoto }
    }
    // maneja: { "artist": {} }, { "data": {} }, { "user": {} }, o campos en raíz
    let artist: Inner?
    let data: Inner?
    let user: Inner?
    let certifications: [Certification]?

    var resolved: String?     { artist?.resolvedAvatar ?? data?.resolvedAvatar ?? user?.resolvedAvatar ?? avatar ?? avatarUrl }
    var resolvedName: String? { artist?.resolvedName   ?? data?.resolvedName   ?? user?.resolvedName   ?? name ?? nombre }
    var resolvedCover: String?     { artist?.resolvedCoverInner ?? data?.resolvedCoverInner ?? user?.resolvedCoverInner ?? coverUrl ?? coverPhoto }
    var resolvedInstagram: String? { artist?.instagram  ?? data?.instagram  ?? user?.instagram  ?? instagram }
    var resolvedWebsite: String?   { artist?.website    ?? data?.website    ?? user?.website    ?? website }
    var resolvedCertifications: [Certification] { artist?.certifications ?? data?.certifications ?? user?.certifications ?? certifications ?? [] }
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
    var certifications: [Certification] = []
    var dayOffers: [String: ServiceDayOffer] = [:]  // serviceId → oferta activa hoy
    var isLoadingServices = false
    var isLoadingReviews = false
    var isLoadingPortfolio = false
    var errorMessage: String?

    init(artist: Artist) {
        self.artist = artist
        self.avatarURL = artist.avatarUrl  // carga inmediata desde search; loadArtistDetail lo sobreescribe si hay foto más reciente
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
        // cargar ofertas del día después de tener servicios
        await loadDayOffersForServices()
    }

    func loadArtistDetail() async {
        do {
            let dto: ArtistAvatarResponse = try await APIClient.request(.getArtist(id: artist.id))
            if let url = dto.resolved          { avatarURL = url }
            if let url = dto.resolvedCover     { coverURL = url }
            if let ig  = dto.resolvedInstagram { instagram = ig }
            if let wb  = dto.resolvedWebsite   { website = wb }
            let certs = dto.resolvedCertifications
            if !certs.isEmpty { certifications = certs }
        } catch {}
    }


    func loadDayOffersForServices() async {
        let today = Date()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let isoDay = df.string(from: today)
        await withTaskGroup(of: (String, ServiceDayOffer?).self) { group in
            for svc in services {
                group.addTask {
                    let res: ServiceDayOffersResponse? = try? await APIClient.request(.getServiceDayOffers(serviceId: svc.id))
                    let active = res?.all.first { offer in
                        guard offer.isActive else { return false }
                        if let from = offer.validFrom, from > isoDay { return false }
                        if let until = offer.validUntil, until < isoDay { return false }
                        return true
                    }
                    return (svc.id, active)
                }
            }
            var result: [String: ServiceDayOffer] = [:]
            for await (id, offer) in group {
                if let o = offer { result[id] = o }
            }
            dayOffers = result
        }
    }

    func loadServices() async {
        isLoadingServices = true
        defer { isLoadingServices = false }
        do {
            let res: CatalogServicesResponse = try await APIClient.request(.listServices(artistId: artist.id))
            #if DEBUG
            print("🎨 Services raw count: \(res.services.count) for artistId=\(artist.id)")
            for s in res.services { print("  • [\(s.status ?? "nil")] \(s.name) — \(s.basePrice) \(s.currency) available=\(s.isAvailable ?? true)") }
            #endif
            services = res.services.filter { $0.status == "ACTIVE" }
        } catch {
            #if DEBUG
            print("❌ loadServices error for artistId=\(artist.id): \(error)")
            #endif
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
            #if DEBUG
            print("🖼 Portfolio: \(portfolio.count) items for artistId=\(artist.id)")
            #endif
        } catch {
            #if DEBUG
            print("❌ loadPortfolio error for artistId=\(artist.id): \(error)")
            #endif
            portfolio = []
        }
    }
}
