// HomeViewModel.swift
import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var artists: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCategory: ArtistCategory?
    var hasMore = true
    private var currentPage = 1

    var categories: [ArtistCategory] { ArtistCategory.allCases }

    // MARK: - Actions

    func loadInitial() async {
        currentPage = 1
        artists = []
        hasMore = true
        await loadNext()
    }

    func loadNextIfNeeded(currentItem: Artist) async {
        guard let last = artists.last, last.id == currentItem.id, hasMore, !isLoading else { return }
        await loadNext()
    }

    func selectCategory(_ category: ArtistCategory?) async {
        selectedCategory = category
        await loadInitial()
    }

    // MARK: - Private

    private func loadNext() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: PaginatedResponse<Artist> = try await APIClient.request(
                .listArtists(
                    page: currentPage,
                    limit: 20,
                    category: selectedCategory?.rawValue,
                    cityId: nil,
                    q: nil
                )
            )
            artists.append(contentsOf: res.data)
            hasMore = res.hasMore
            currentPage += 1
        } catch {
            // Fallback mock para desarrollo sin backend
            if artists.isEmpty { artists = Artist.mockList }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
