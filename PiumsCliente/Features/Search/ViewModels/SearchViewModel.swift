// SearchViewModel.swift
import Foundation
import CoreLocation

// Opciones de ordenamiento que acepta el backend
enum SearchSortOption: String, CaseIterable {
    case relevance  = ""
    case ratingDesc = "rating"
    case priceAsc   = "price_asc"
    case priceDesc  = "price_desc"
    case newest     = "newest"

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

// Especialidades reales que existen en el backend (texto libre)
enum SpecialtyOption: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case bodas         = "Bodas"
    case dj            = "DJ"
    case musico        = "Música"
    case fotografia    = "Fotografía"
    case baile         = "Baile"
    case maquillaje    = "Maquillaje"
    case tatuajes      = "Tatuajes"
    case iluminacion   = "Iluminación"
    case barberia      = "Barbería"
    case quinces       = "Quinceañeras"
    case corporativo   = "Corporativo"

    var icon: String {
        switch self {
        case .bodas:       return "heart.fill"
        case .dj:          return "headphones"
        case .musico:      return "music.note"
        case .fotografia:  return "camera.fill"
        case .baile:       return "figure.dance"
        case .maquillaje:  return "paintbrush.fill"
        case .tatuajes:    return "pencil.tip"
        case .iluminacion: return "lightbulb.fill"
        case .barberia:    return "scissors"
        case .quinces:     return "sparkles"
        case .corporativo: return "briefcase.fill"
        }
    }
}

@Observable
@MainActor
final class SearchViewModel {
    // MARK: - Filtros
    var query          = ""
    var selectedSpecialty: SpecialtyOption? = nil
    var selectedTalentId: String? = nil
    var selectedTalentLabel: String? = nil
    var minPrice: Double = 0        // en quetzales (se convierte a centavos para API)
    var maxPrice: Double = 50000    // Q500.00 max (en centavos)
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
        isLoading = false   // cancela la guarda de la búsqueda anterior
        currentPage = 1
        currentSmartPage = 1
        results = []
        smartResults = []
        expandedTerms = []
        hasMore = true
        hasSearched = true
        let effectiveQuery = query.trimmingCharacters(in: .whitespaces).isEmpty
            ? (selectedTalentLabel ?? "")
            : query.trimmingCharacters(in: .whitespaces)
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
        selectedTalentId = nil
        selectedTalentLabel = nil
        minPrice = 0
        maxPrice = 50000
        minRating = 0
        selectedCity = nil
        isVerified = false
        sortOption = .relevance
    }

    var hasActiveFilters: Bool {
        selectedSpecialty != nil || selectedTalentId != nil || minPrice > 0 || maxPrice < 50000 ||
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
                    q: query.trimmingCharacters(in: .whitespaces).isEmpty ? (selectedTalentLabel ?? "") : query.trimmingCharacters(in: .whitespaces),
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
            smartResults.append(contentsOf: res.artists)
            if currentSmartPage == 1 {
                expandedTerms = res.expandedTerms ?? []
            }
            results = smartResults.map { $0.toArtist() }
            hasMore = res.pagination?.hasMore ?? false
            currentSmartPage += 1
        } catch {
            guard nonce == searchNonce else { return }
            errorMessage = AppError(from: error).errorDescription
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
            results.append(contentsOf: res.artists)
            hasMore = res.pagination.hasMore
            currentPage += 1
        } catch {
            guard nonce == searchNonce else { return }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
