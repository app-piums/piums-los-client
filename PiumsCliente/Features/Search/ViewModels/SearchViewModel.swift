// SearchViewModel.swift
import Foundation

@Observable
@MainActor
final class SearchViewModel {
    // MARK: - Filtros
    var query = ""
    var selectedCategory: ArtistCategory?
    var maxPrice: Double = 5000     // en quetzales (no centavos)
    var minRating: Double = 0
    var selectedCity: String?

    // MARK: - Estado
    var results: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var hasMore = true
    private var currentPage = 1

    var cities = ["Ciudad de Guatemala", "Antigua", "Quetzaltenango", "Cobán", "Escuintla"]

    // MARK: - Actions

    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        currentPage = 1
        results = []
        hasMore = true
        hasSearched = true
        await loadNext(isInitial: true)
    }

    func loadNextIfNeeded(currentItem: Artist) async {
        guard let last = results.last, last.id == currentItem.id, hasMore, !isLoading else { return }
        await loadNext(isInitial: false)
    }

    func clearFilters() {
        selectedCategory = nil
        maxPrice = 5000
        minRating = 0
        selectedCity = nil
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || maxPrice < 5000 || minRating > 0 || selectedCity != nil
    }

    // MARK: - Private

    private func loadNext(isInitial: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: PaginatedResponse<Artist> = try await APIClient.request(
                .searchArtists(q: query, page: currentPage)
            )
            // Aplicar filtros cliente-side mientras el backend no los soporte en search
            let filtered = res.data.filter { artist in
                let priceOk  = artist.basePrice.map { Double($0) / 100 <= maxPrice } ?? true
                let ratingOk = (artist.rating ?? 0) >= minRating
                let catOk    = selectedCategory == nil || artist.category == selectedCategory
                let cityOk   = selectedCity == nil || artist.city == selectedCity
                return priceOk && ratingOk && catOk && cityOk
            }
            results.append(contentsOf: filtered)
            hasMore = res.hasMore
            currentPage += 1
        } catch {
            // Fallback mock para desarrollo
            if isInitial {
                results = Artist.mockList.filter {
                    $0.artistName.localizedCaseInsensitiveContains(query) ||
                    $0.category.displayName.localizedCaseInsensitiveContains(query)
                }
            }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
