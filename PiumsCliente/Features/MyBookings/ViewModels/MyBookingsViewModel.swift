// MyBookingsViewModel.swift
import Foundation

struct BookingArtistInfo {
    let name: String
    let avatar: String?
    let specialty: String?
    let isVerified: Bool
}

struct BookingServiceInfo {
    let name: String
    let description: String?
    let whatIsIncluded: [String]
    let durationMin: Int?
    let durationMax: Int?
}

// DTO privado para decodificar /api/artists/:id
private struct ArtistSummaryDTO: Decodable {
    let name: String?
    let nombre: String?     // backend puede usar "nombre" en vez de "name"
    let avatar: String?
    let specialties: [String]?
    let isVerified: Bool?
    struct Nested: Decodable {
        let name: String?
        let nombre: String?
        let avatar: String?
        let specialties: [String]?
        let isVerified: Bool?
        var resolvedName: String? { name ?? nombre }
    }
    // maneja: { "artist": {} }, { "data": {} }, { "user": {} }, o campos en raíz
    let artist: Nested?
    let data: Nested?
    let user: Nested?
    var resolvedName: String?      { artist?.resolvedName ?? data?.resolvedName ?? user?.resolvedName ?? name ?? nombre }
    var resolvedAvatar: String?    { artist?.avatar ?? data?.avatar ?? user?.avatar ?? avatar }
    var resolvedSpecialty: String? { (artist?.specialties ?? data?.specialties ?? user?.specialties ?? specialties)?.first }
    var resolvedVerified: Bool     { artist?.isVerified ?? data?.isVerified ?? user?.isVerified ?? isVerified ?? false }
}

// DTO para decodificar /api/catalog/services/:id (maneja respuesta directa o envuelta)
private struct ServiceResponseDTO: Decodable {
    let service: ArtistService?
    let data: ArtistService?
    // campos directos como fallback
    let id: String?
    let name: String?
    let description: String?
    let whatIsIncluded: [String]?
    let durationMin: Int?
    let durationMax: Int?

    var resolved: ArtistService? { service ?? data }
}

@Observable
@MainActor
final class MyBookingsViewModel {
    var bookings: [Booking] = []
    var artistCache: [String: BookingArtistInfo] = [:]
    var serviceCache: [String: BookingServiceInfo] = [:]
    var isLoading = false
    var errorMessage: String?
    var selectedStatus: BookingStatus?
    var hasMore = true
    private var currentPage = 1

    let statusFilters: [BookingStatus?] = [
        nil, .pending, .confirmed, .paymentPending, .inProgress,
        .reschedulePendingClient, .delivered, .completed, .disputeOpen, .cancelledClient
    ]

    func statusLabel(_ s: BookingStatus?) -> String {
        s?.displayName ?? "Todas"
    }

    func loadInitial() async {
        currentPage = 1
        bookings = []
        hasMore = true
        await loadNext()
    }

    func loadNextIfNeeded(item: Booking) async {
        guard let last = bookings.last, last.id == item.id, hasMore, !isLoading else { return }
        await loadNext()
    }

    func selectStatus(_ status: BookingStatus?) async {
        selectedStatus = status
        await loadInitial()
    }

    func cancelBooking(id: String) async {
        do {
            let _: EmptyResponse = try await APIClient.request(.cancelBooking(id: id))
            bookings.removeAll { $0.id == id }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func loadNext() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // .paymentPending filtra por paymentStatus=PENDING para capturar
            // reservas en cualquier BookingStatus que aún no han pagado.
            let statusParam: String?
            let paymentStatusParam: String?
            if selectedStatus == .paymentPending {
                statusParam = nil
                paymentStatusParam = "PENDING"
            } else {
                statusParam = selectedStatus?.rawValue
                paymentStatusParam = nil
            }
            let res: BookingsResponse = try await APIClient.request(
                .listMyBookings(status: statusParam, paymentStatus: paymentStatusParam, page: currentPage)
            )
            print("📋 Bookings cargadas: \(res.allBookings.count) — bookings:\(res.bookings?.count ?? -1) data:\(res.data?.count ?? -1) items:\(res.items?.count ?? -1)")
            let newBookings = res.allBookings
            bookings.append(contentsOf: newBookings)
            hasMore = res.hasMore
            currentPage += 1
            // Precargar info de artistas y servicios en paralelo
            async let fetchArtists: () = prefetchArtists(for: newBookings)
            async let fetchServices: () = prefetchServices(for: newBookings)
            _ = await (fetchArtists, fetchServices)
        } catch {
            let err = AppError(from: error)
            print("❌ Error cargando bookings: \(err.errorDescription ?? error.localizedDescription)")
            errorMessage = err.errorDescription
        }
    }

    private func prefetchArtists(for bookings: [Booking]) async {
        let ids = Set(bookings.map { $0.artistId }).filter { artistCache[$0] == nil }
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { await self.loadArtistInfo(id: id) }
            }
        }
    }

    private func prefetchServices(for bookings: [Booking]) async {
        let ids = Set(bookings.map { $0.serviceId }).filter { serviceCache[$0] == nil }
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { await self.loadServiceInfo(id: id) }
            }
        }
    }

    private func loadArtistInfo(id: String) async {
        if let dto: ArtistSummaryDTO = try? await APIClient.request(.getArtist(id: id)) {
            print("🎨 prefetch \(id) — resolvedName: \(dto.resolvedName ?? "nil"), artist?.name: \(dto.artist?.name ?? "nil"), data?.name: \(dto.data?.name ?? "nil"), name: \(dto.name ?? "nil")")
            guard let name = dto.resolvedName else { return }
            artistCache[id] = BookingArtistInfo(
                name: name,
                avatar: dto.resolvedAvatar,
                specialty: dto.resolvedSpecialty,
                isVerified: dto.resolvedVerified
            )
        } else {
            print("❌ prefetch artista \(id) — fetch/decode falló")
        }
    }

    private func loadServiceInfo(id: String) async {
        // Intenta decodificar respuesta directa (ArtistService) o envuelta
        if let svc: ArtistService = try? await APIClient.request(.getService(id: id)) {
            serviceCache[id] = BookingServiceInfo(
                name: svc.name,
                description: svc.description,
                whatIsIncluded: svc.whatIsIncluded ?? [],
                durationMin: svc.durationMin,
                durationMax: svc.durationMax
            )
            return
        }
        if let dto: ServiceResponseDTO = try? await APIClient.request(.getService(id: id)),
           let svc = dto.resolved {
            serviceCache[id] = BookingServiceInfo(
                name: svc.name,
                description: svc.description,
                whatIsIncluded: svc.whatIsIncluded ?? [],
                durationMin: svc.durationMin,
                durationMax: svc.durationMax
            )
        }
    }
}
