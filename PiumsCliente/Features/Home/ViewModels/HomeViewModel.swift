// HomeViewModel.swift
import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var artists: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    var hasMore = true
    private var currentPage = 1

    // ── Datos del usuario ─────────────────────────────────
    var firstName: String {
        let name = AuthManager.shared.currentUser?.nombre ?? "there"
        return name.components(separatedBy: " ").first ?? name
    }

    // ── Calendario ────────────────────────────────────────
    /// Fechas con reservas confirmadas "yyyy-MM-dd"
    var upcomingBookingDates: Set<String> = []
    var nextBooking: Booking?

    var categories: [ArtistCategory] { ArtistCategory.allCases }

    // MARK: - Actions

    func loadInitial() async {
        currentPage = 1
        artists = []
        hasMore = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadArtists() }
            group.addTask { await self.loadUpcomingBookings() }
        }
    }

    func loadNextIfNeeded(currentItem: Artist) async {
        guard let last = artists.last, last.id == currentItem.id, hasMore, !isLoading else { return }
        await loadArtists()
    }

    // MARK: - Private

    private func loadArtists() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: SearchArtistsResponse = try await APIClient.request(
                .searchArtists(q: nil, page: currentPage, limit: 20,
                               specialty: nil, city: nil,
                               minPrice: nil, maxPrice: nil, minRating: nil,
                               isVerified: nil, sortBy: nil, sortOrder: nil)
            )
            artists.append(contentsOf: res.artists)
            hasMore = res.pagination.hasMore
            currentPage += 1
        } catch {
            if artists.isEmpty { artists = Artist.mockList }
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func loadUpcomingBookings() async {
        do {
            let res: BookingsResponse = try await APIClient.request(
                .listMyBookings(status: "confirmed", page: 1)
            )
            upcomingBookingDates = Set(res.bookings.map { $0.scheduledDate })
            // Próxima reserva = la más cercana en el futuro
            let today = Date()
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            nextBooking = res.bookings
                .filter { fmt.date(from: $0.scheduledDate).map { $0 >= today } ?? false }
                .sorted { $0.scheduledDate < $1.scheduledDate }
                .first
        } catch {
            // No es crítico — el calendario simplemente no mostrará dots
        }
    }
}
