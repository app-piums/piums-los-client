// HomeViewModel.swift
import Foundation

private let interestToSpecialty: [String: String] = [
    "live-music":       "MUSICO",
    "dj":               "MUSICO",
    "photography":      "FOTOGRAFO",
    "video":            "VIDEOGRAFO",
    "music-production": "MUSICO",
    "dance":            "ANIMADOR",
    "magic":            "ANIMADOR",
]

let categoryLabels: [String: String] = [
    "MUSICO":     "Músicos para ti",
    "FOTOGRAFO":  "Fotógrafos para ti",
    "VIDEOGRAFO": "Videógrafos para ti",
    "ANIMADOR":   "Animadores para ti",
]

@Observable
@MainActor
final class HomeViewModel {
    var artists: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    var hasMore = true
    private var currentPage = 1
    private var lastLoadedAt: Date?

    var personalizedSections: [(category: String, label: String, artists: [Artist])] = []

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
        lastLoadedAt = Date()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadArtists() }
            group.addTask { await self.loadUpcomingBookings() }
            group.addTask { await self.loadPersonalized() }
        }
    }

    /// Refresca silenciosamente si los datos tienen más de 60 s (al volver de una navegación).
    /// Evita reload visible en navegaciones rápidas pero garantiza fotos actualizadas.
    func refreshIfStale() async {
        guard let last = lastLoadedAt, Date().timeIntervalSince(last) > 60 else { return }
        await loadInitial()
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
            artists.append(contentsOf: res.artists.filter { $0.servicesCount > 0 })
            hasMore = res.pagination.hasMore
            currentPage += 1
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func loadPersonalized() async {
        guard let interests = UserInterests.load(), !interests.categories.isEmpty else { return }
        let categories = Array(Set(interests.categories.compactMap { interestToSpecialty[$0] }))
        var sections: [(category: String, label: String, artists: [Artist])] = []
        for cat in categories {
            guard let label = categoryLabels[cat] else { continue }
            if let res: SearchArtistsResponse = try? await APIClient.request(
                .searchArtists(q: nil, page: 1, limit: 8,
                               specialty: cat, city: nil,
                               minPrice: nil, maxPrice: nil, minRating: nil,
                               isVerified: nil, sortBy: nil, sortOrder: nil)
            ) {
                let filtered = res.artists.filter { $0.servicesCount > 0 }
                if !filtered.isEmpty {
                    sections.append((category: cat, label: label, artists: filtered))
                }
            }
        }
        personalizedSections = sections
    }

    private func loadUpcomingBookings() async {
        let activeStatuses: Set<BookingStatus> = [.confirmed, .pending, .inProgress, .rescheduled]
        do {
            // Sin filtro de status — igual que Android, filtramos localmente para incluir PENDING/RESCHEDULED
            let res: BookingsResponse = try await APIClient.request(
                .listMyBookings(status: nil, paymentStatus: nil, page: 1)
            )
            let active = res.allBookings.filter { activeStatuses.contains($0.status) }
            // Recortar a "yyyy-MM-dd" — el backend devuelve datetime ISO completo ("2026-06-07T09:00:00Z")
            upcomingBookingDates = Set(active.map { String($0.scheduledDate.prefix(10)) })
            // Próxima reserva = la más cercana en el futuro
            let today = Date()
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            nextBooking = active
                .filter { b in
                    guard let d = fmt.date(from: String(b.scheduledDate.prefix(10))) else { return false }
                    return d >= today
                }
                .sorted { $0.scheduledDate < $1.scheduledDate }
                .first
        } catch {
            // No es crítico — el calendario simplemente no mostrará dots
        }
    }
}
