// SearchViewModel.swift
import Foundation
import CoreLocation

// Opciones de ordenamiento que acepta el backend
enum SearchSortOption: String, CaseIterable {
    case relevance  = ""
    case ratingDesc = "rating"
    case priceAsc   = "price_low"
    case priceDesc  = "price_high"
    case newest     = "recent"

    var displayName: String {
        switch self {
        case .relevance:  return "Relevancia"
        case .ratingDesc: return "Mejor calificados"
        case .priceAsc:   return "Precio: menor a mayor"
        case .priceDesc:  return "Precio: mayor a menor"
        case .newest:     return "Más recientes"
        }
    }
}

// Categorías oficiales del backend — ArtistCategory enum de piums-platform
enum SpecialtyOption: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case musico    = "MUSICO"
    case fotografo = "FOTOGRAFO"
    case videografo = "VIDEOGRAFO"
    case animador  = "ANIMADOR"

    var displayName: String {
        switch self {
        case .musico:    return "Música"
        case .fotografo: return "Fotografía"
        case .videografo: return "Video"
        case .animador:  return "Animador"
        }
    }

    var icon: String {
        switch self {
        case .musico:    return "music.note"
        case .fotografo: return "camera.fill"
        case .videografo: return "film.fill"
        case .animador:  return "party.popper.fill"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .musico:    return ["música", "musica", "músico", "musico", "music"]
        case .fotografo: return ["fotografía", "fotografia", "fotógrafo", "fotografo", "foto"]
        case .videografo: return ["video", "videógrafo", "videografo"]
        case .animador:  return ["animador", "animación", "animacion", "payaso", "entretenimiento"]
        }
    }
}

@Observable
@MainActor
final class SearchViewModel {
    // MARK: - Filtros
    var query          = ""
    var selectedSpecialty: SpecialtyOption? = nil
    var minPrice: Double = 0        // en centavos USD (se envía directo a API)
    var maxPrice: Double = 50000    // $500.00 max (en centavos)
    var minRating: Double = 0
    var selectedCity: String?
    var isVerified: Bool = false
    var sortOption: SearchSortOption = .relevance

    // MARK: - SmartSearch results
    var smartResults: [SmartArtist] = []
    var expandedTerms: [String] = []
    var isSmartSearch: Bool = false

    // Ubicación del usuario para SmartSearch con lat/lng
    var userLocation: CLLocationCoordinate2D? = nil

    // MARK: - Estado
    var results: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var hasMore = true
    private var currentPage = 1
    private var currentSmartPage = 1
    private var searchNonce = 0

    // Ciudades reales extraídas del backend
    var cities = ["Guatemala", "Ciudad de Guatemala", "Antigua Guatemala",
                  "Quetzaltenango", "Cobán", "Escuintla", "Huehuetenango",
                  "Flores", "Chiquimula"]

    // MARK: - Actions

    func search() async {
        searchNonce += 1
        isLoading = false
        currentPage = 1
        currentSmartPage = 1
        results = []
        smartResults = []
        expandedTerms = []
        hasMore = true
        hasSearched = true
        let trimmedQ = query.trimmingCharacters(in: .whitespaces)
        let effectiveQuery = trimmedQ

        // Si el query es exactamente el nombre de una categoría y no hay otra categoría activa,
        // usar búsqueda regular con filtro category= en lugar de SmartSearch — el SmartSearch
        // hace text matching en serviceTitles/bio y puede traer artistas no relacionados.
        let normalizedQ = effectiveQuery
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        if selectedSpecialty == nil,
           let categoryMatch = SpecialtyOption.allCases.first(where: { sp in
               sp.searchKeywords.contains { kw in
                   kw.folding(options: .diacriticInsensitive, locale: .current)
                     .lowercased() == normalizedQ
               }
           }) {
            selectedSpecialty = categoryMatch
            query = ""
            isSmartSearch = false
            await loadNext()
            return
        }

        isSmartSearch = !effectiveQuery.isEmpty
        if isSmartSearch {
            await loadSmart()
        } else {
            await loadNext()
        }
    }

    func loadNextIfNeeded(currentItem: Artist) async {
        guard let last = results.last, last.id == currentItem.id, hasMore, !isLoading else { return }
        if isSmartSearch {
            await loadSmart()
        } else {
            await loadNext()
        }
    }

    func clearFilters() {
        selectedSpecialty = nil
        minPrice = 0
        maxPrice = 50000
        minRating = 0
        selectedCity = nil
        isVerified = false
        sortOption = .relevance
    }

    var hasActiveFilters: Bool {
        selectedSpecialty != nil || minPrice > 0 || maxPrice < 50000 ||
        minRating > 0 || selectedCity != nil || isVerified || sortOption != .relevance
    }

    // MARK: - Private

    private func loadSmart() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let nonce = searchNonce
        do {
            let res: SmartSearchResponse = try await APIClient.request(
                .smartSearch(
                    q: query.trimmingCharacters(in: .whitespaces),
                    city: selectedCity,
                    lat: userLocation?.latitude,
                    lng: userLocation?.longitude,
                    page: currentSmartPage,
                    limit: 20,
                    specialty: selectedSpecialty?.rawValue,
                    minPrice: minPrice > 0 ? Int(minPrice) : nil,
                    maxPrice: maxPrice < 50000 ? Int(maxPrice) : nil,
                    minRating: minRating > 0 ? minRating : nil,
                    isVerified: isVerified ? true : nil,
                    sortBy: sortOption == .relevance ? nil : sortOption.rawValue,
                    sortOrder: sortOption == .priceAsc ? "asc" : (sortOption == .relevance ? nil : "desc")
                )
            )
            guard nonce == searchNonce else { return }
            smartResults.append(contentsOf: res.artists.filter { $0.servicesCount > 0 })
            if currentSmartPage == 1 {
                expandedTerms = res.expandedTerms ?? []
            }
            results = smartResults.map { $0.toArtist() }
            hasMore = res.pagination?.hasMore ?? false
            currentSmartPage += 1
        } catch {
            guard nonce == searchNonce else { return }
            let appErr = AppError(from: error)
            // Smart search no disponible (5xx/504) → fallback al índice rápido
            let is5xx: Bool
            if case .http(let code, _) = appErr, code >= 500 { is5xx = true }
            else { is5xx = (appErr == .serverError) }
            if is5xx {
                isSmartSearch = false
                expandedTerms = []
                await loadNext()
            } else {
                errorMessage = appErr.errorDescription
            }
        }
    }

    private func loadNext() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let nonce = searchNonce
        do {
            let endpoint = APIEndpoint.searchArtists(
                q: query.trimmingCharacters(in: .whitespaces),
                page: currentPage,
                limit: 20,
                specialty: selectedSpecialty?.rawValue,
                city: selectedCity,
                minPrice: minPrice > 0 ? Int(minPrice) : nil,
                maxPrice: maxPrice < 50000 ? Int(maxPrice) : nil,
                minRating: minRating > 0 ? minRating : nil,
                isVerified: isVerified ? true : nil,
                sortBy: sortOption == .relevance ? nil : sortOption.rawValue,
                sortOrder: sortOption == .priceAsc ? "asc" : (sortOption == .relevance ? nil : "desc")
            )
            let res: SearchArtistsResponse = try await APIClient.request(endpoint)
            guard nonce == searchNonce else { return }
            results.append(contentsOf: res.artists.filter { $0.servicesCount > 0 })
            hasMore = res.pagination.hasMore
            currentPage += 1
        } catch {
            guard nonce == searchNonce else { return }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
