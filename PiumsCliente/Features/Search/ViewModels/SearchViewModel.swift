// SearchViewModel.swift
import Foundation

@Observable
@MainActor
final class SearchViewModel {
    // MARK: - Filtros
    var query = ""
    var selectedCategory: ArtistCategory?
    var maxPrice: Double = 5000
    var minRating: Double = 0
    var selectedCity: String?

    // MARK: - Estado
    var results: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var hasMore = true
    private var currentPage = 1

    var cities = ["Ciudad de Guatemala", "Antigua Guatemala", "Quetzaltenango", "Cobán", "Escuintla", "Chiquimula"]

    // MARK: - Actions

    func search() async {
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
            let res: SearchArtistsResponse = try await APIClient.request(
                .searchArtists(
                    q: query.trimmingCharacters(in: .whitespaces),
                    page: currentPage,
                    limit: 20,
                    category: selectedCategory?.rawValue,
                    cityId: selectedCity
                )
            )
            // Aplicar filtros cliente-side de precio y rating (backend no los soporta en search)
            let filtered = res.artists.filter { artist in
                let priceOk  = artist.mainServicePrice.map { Double($0) / 100 <= maxPrice } ?? true
                let ratingOk = (artist.averageRating ?? 0) >= minRating
                return priceOk && ratingOk
            }
            results.append(contentsOf: filtered)
            hasMore = res.pagination.hasMore
            currentPage += 1
        } catch {
            if isInitial {
                let q = query.lowercased()
                results = Artist.mockList.filter {
                    $0.name.localizedCaseInsensitiveContains(q) ||
                    ($0.specialties?.joined(separator: " ").localizedCaseInsensitiveContains(q) ?? false)
                }
            }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
