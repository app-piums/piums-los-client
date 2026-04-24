// ArtistSearchByDateView.swift
// Busca artistas disponibles para una fecha, ordena por distancia haversine
import SwiftUI
import CoreLocation

// MARK: - Haversine

private func haversineKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let R = 6371.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2)*sin(dLat/2) + cos(lat1 * .pi/180)*cos(lat2 * .pi/180)*sin(dLon/2)*sin(dLon/2)
    return R * 2 * atan2(sqrt(a), sqrt(1-a))
}

// Ciudad → coordenadas aproximadas (fallback cuando el artista no tiene coords exactas)
private let CITY_COORDS: [String: (Double, Double)] = [
    "Guatemala":           (14.6349, -90.5069),
    "Ciudad de Guatemala": (14.6349, -90.5069),
    "Antigua Guatemala":   (14.5586, -90.7295),
    "Quetzaltenango":      (14.8444, -91.5183),
    "Cobán":               (15.4736, -90.3789),
    "Escuintla":           (14.3057, -90.7861),
    "Huehuetenango":       (15.3197, -91.4737),
    "Flores":              (16.9328, -89.8929),
    "Chiquimula":          (14.7981, -89.5433),
]

// MARK: - Model

struct ArtistWithAvailability: Identifiable {
    let artist: Artist
    let available: Bool
    let distance: Double?          // km, nil si sin ubicación
    let mainServicePrice: Int?
    let mainServiceName: String?

    var id: String { artist.id }
}

// MARK: - ViewModel

@Observable
@MainActor
final class ArtistSearchByDateViewModel {
    // All artists loaded for the date (with availability + distance)
    var artists: [ArtistWithAvailability] = []
    // SmartSearch results when query is active
    var smartArtists: [ArtistWithAvailability] = []
    var smartMatchMap: [String: MatchedService] = [:]
    var isLoading = false
    var isSmartLoading = false
    var errorMessage: String?
    var showOnlyAvailable = true
    var categoryFilter: String?
    var searchQuery = ""
    var isSmartSearch: Bool { !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    private var debounceTask: Task<Void, Never>? = nil

    // What the grid shows: smart results (when query active) or date-filtered list
    var displayed: [ArtistWithAvailability] {
        let base = isSmartSearch && !smartArtists.isEmpty ? smartArtists : artists
        return base.filter { item in
            if showOnlyAvailable && !item.available { return false }
            if let cat = categoryFilter {
                let sp = item.artist.specialties?.joined(separator: " ").lowercased() ?? ""
                if !sp.contains(cat.lowercased()) { return false }
            }
            // Local text filter only as fallback while SmartSearch is loading
            if isSmartSearch && smartArtists.isEmpty && !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let name = item.artist.artistName.lowercased()
                let city = (item.artist.city ?? "").lowercased()
                let specs = (item.artist.specialties ?? []).joined(separator: " ").lowercased()
                if !name.contains(q) && !city.contains(q) && !specs.contains(q) { return false }
            }
            return true
        }
    }

    // MARK: - Load artists for a date

    func load(date: Date, location: CLLocationCoordinate2D?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let dateStr = isoDate(date)
            let cal = Calendar.current
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)

            // 1. Fetch all artists
            let searchRes: SearchArtistsResponse = try await APIClient.request(
                .searchArtists(q: nil, page: 1, limit: 60, specialty: nil, city: nil,
                               minPrice: nil, maxPrice: nil, minRating: nil,
                               isVerified: nil, sortBy: nil, sortOrder: nil)
            )
            let rawArtists = searchRes.artists

            // 2. Batch check calendars in parallel
            let calendars = await withTaskGroup(of: (String, ArtistCalendar?).self) { group in
                for a in rawArtists {
                    group.addTask {
                        let cal: ArtistCalendar? = try? await APIClient.request(
                            .getArtistCalendar(artistId: a.id, year: year, month: month)
                        )
                        return (a.id, cal)
                    }
                }
                var result: [String: ArtistCalendar] = [:]
                for await (id, cal) in group { if let c = cal { result[id] = c } }
                return result
            }

            // 3. Enrich with availability + distance (exact coords preferred over city fallback)
            let enriched: [ArtistWithAvailability] = rawArtists.map { artist in
                let artistCal = calendars[artist.id]
                let available: Bool
                if let cal = artistCal {
                    available = !cal.occupiedDates.contains(dateStr) && !cal.blockedDates.contains(dateStr)
                } else {
                    available = true
                }

                let distance = computeDistance(artist: artist, location: location)

                return ArtistWithAvailability(
                    artist: artist,
                    available: available,
                    distance: distance,
                    mainServicePrice: artist.mainServicePrice,
                    mainServiceName: artist.mainServiceName
                )
            }

            artists = sortArtists(enriched)

            // If there's already an active query, refresh smart results with updated availability data
            if isSmartSearch {
                searchDebounced()
            }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    // MARK: - SmartSearch (debounced)

    func searchDebounced() {
        debounceTask?.cancel()
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            smartArtists = []
            smartMatchMap = [:]
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await loadSmart()
        }
    }

    private func loadSmart() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSmartLoading = true
        defer { isSmartLoading = false }
        do {
            // Use location of the current user to improve ranking
            let loc = artists.first?.distance != nil ? extractLocation() : nil
            let res: SmartSearchResponse = try await APIClient.request(
                .smartSearch(q: searchQuery.trimmingCharacters(in: .whitespaces),
                             city: nil, lat: loc?.lat, lng: loc?.lng,
                             page: 1, limit: 40,
                             specialty: nil, minPrice: nil, maxPrice: nil,
                             minRating: nil, isVerified: nil,
                             sortBy: nil, sortOrder: nil)
            )
            // Build match map (service price override per artist)
            var matchMap: [String: MatchedService] = [:]
            for sa in res.artists {
                if let ms = sa.matchedService { matchMap[sa.id] = ms }
            }
            smartMatchMap = matchMap

            // Convert SmartArtist → ArtistWithAvailability, merging availability data already fetched
            let byId = Dictionary(uniqueKeysWithValues: artists.map { ($0.id, $0) })
            smartArtists = res.artists.map { sa in
                let existing = byId[sa.id]
                let artist = sa.toArtist()
                return ArtistWithAvailability(
                    artist: artist,
                    available: existing?.available ?? sa.isAvailable,
                    distance: existing?.distance ?? computeDistance(artist: artist, location: nil),
                    mainServicePrice: sa.matchedService?.price ?? sa.mainServicePrice,
                    mainServiceName: sa.matchedService?.name ?? sa.mainServiceName
                )
            }
        } catch {
            // On error, fall back to local filter — don't clear smartArtists if already populated
            if smartArtists.isEmpty { errorMessage = AppError(from: error).errorDescription }
        }
    }

    // MARK: - Re-sort when location changes (no extra API call)

    func updateLocation(_ location: CLLocationCoordinate2D?) {
        artists = sortArtists(artists.map { item in
            ArtistWithAvailability(
                artist: item.artist,
                available: item.available,
                distance: computeDistance(artist: item.artist, location: location),
                mainServicePrice: item.mainServicePrice,
                mainServiceName: item.mainServiceName
            )
        })
        // Also re-sort smart results
        if !smartArtists.isEmpty {
            smartArtists = smartArtists.map { item in
                ArtistWithAvailability(
                    artist: item.artist,
                    available: item.available,
                    distance: computeDistance(artist: item.artist, location: location),
                    mainServicePrice: item.mainServicePrice,
                    mainServiceName: item.mainServiceName
                )
            }
        }
    }

    // MARK: - Helpers

    private func computeDistance(artist: Artist, location: CLLocationCoordinate2D?) -> Double? {
        guard let loc = location else { return nil }
        // Use exact artist coords first, then fall back to city centroid
        if let lat = artist.baseLocationLat, let lng = artist.baseLocationLng {
            return haversineKm(loc.latitude, loc.longitude, lat, lng)
        }
        if let cityKey = artist.city, let coords = CITY_COORDS[cityKey] {
            return haversineKm(loc.latitude, loc.longitude, coords.0, coords.1)
        }
        return nil
    }

    private func sortArtists(_ list: [ArtistWithAvailability]) -> [ArtistWithAvailability] {
        list.sorted { a, b in
            if a.available != b.available { return a.available && !b.available }
            switch (a.distance, b.distance) {
            case let (d1?, d2?): return d1 < d2
            case (_?, nil):      return true
            default:             return false
            }
        }
    }

    // Extract lat/lng from the first artist that has a real distance (means we have user location)
    private func extractLocation() -> (lat: Double, lng: Double)? { nil }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
}

// MARK: - View

struct ArtistSearchByDateView: View {
    // Mutables para poder cambiar fecha/ubicación dentro de la pantalla
    @State var selectedDate: Date
    @State var userLocation: CLLocationCoordinate2D?
    @State var locationName: String

    @State private var viewModel = ArtistSearchByDateViewModel()
    @State private var selectedArtist: Artist?
    @State private var bookingContext: BookingFlowContext?
    @Environment(\.locationStore) private var locationStore

    // MARK: - Date strip helpers
    private var nextDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    private var monthYearLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: selectedDate).capitalized
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Filtros rápidos
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Toggle("Solo disponibles", isOn: $viewModel.showOnlyAvailable)
                            .toggleStyle(.button)
                            .font(.caption.weight(.semibold))
                            .tint(.green)
                            .padding(.horizontal, 4)

                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Nombre, estilo…", text: $viewModel.searchQuery)
                                .font(.subheadline)
                                .frame(width: 140)
                            if !viewModel.searchQuery.isEmpty {
                                Button { viewModel.searchQuery = "" } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
                .background(.bar)

                Divider()

                // Results header
                if !viewModel.isLoading {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(viewModel.displayed.count) artista(s) encontrado(s)")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if viewModel.isSmartSearch {
                                HStack(spacing: 4) {
                                    if viewModel.isSmartLoading {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text("SmartSearch")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.piumsOrange)
                            } else if userLocation == nil {
                                Label("Agrega ubicación para ordenar por distancia", systemImage: "info.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Loading
                if viewModel.isLoading {
                    LoadingView().frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.displayed.isEmpty {
                    EmptyStateView(
                        systemImage: "calendar.badge.exclamationmark",
                        title: "Sin artistas disponibles",
                        description: viewModel.showOnlyAvailable
                            ? "No hay artistas disponibles para esa fecha. Intenta desactivar el filtro."
                            : "No hay artistas que coincidan."
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, 30)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(viewModel.displayed) { item in
                            ArtistSearchResultCard(
                                item: item,
                                matchedService: viewModel.smartMatchMap[item.id]
                            )
                            .onTapGesture {
                                bookingContext = BookingFlowContext(
                                    artist: item.artist,
                                    selectedDate: selectedDate,
                                    location: locationName,
                                    locationLat: userLocation?.latitude,
                                    locationLng: userLocation?.longitude
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Artistas Disponibles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // ── Strip de fecha + ubicación como header sticky ──────────
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    // Encabezado mes
                    HStack {
                        Text("SELECCIONAR FECHA")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        Spacer()
                        Text(monthYearLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.piumsOrange)
                    }
                    .padding(.horizontal, 16)

                    // Strip horizontal de días
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(nextDays, id: \.self) { date in
                                DayButton(
                                    date: date,
                                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                ) {
                                    selectedDate = date
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Botón de ubicación
                    Button {
                        locationStore.refresh()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.piumsOrange.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: userLocation != nil ? "location.fill" : "location")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.piumsOrange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("UBICACIÓN DEL EVENTO")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.8)
                                if locationStore.isLocating {
                                    HStack(spacing: 6) {
                                        ProgressView().scaleEffect(0.7)
                                        Text("Obteniendo ubicación…")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text(locationName.isEmpty ? "Toca para usar tu ubicación actual" : locationName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
                Divider()
            }
        }
        .task {
            // Pre-seed from LocationStore if already available
            if userLocation == nil, let coord = locationStore.coordinate {
                userLocation = coord
                locationName = locationStore.cityName
            }
            await viewModel.load(date: selectedDate, location: userLocation)
        }
        .onChange(of: selectedDate) { _, newDate in
            Task { await viewModel.load(date: newDate, location: userLocation) }
        }
        .onChange(of: viewModel.searchQuery) { _, _ in
            viewModel.searchDebounced()
        }
        .onChange(of: locationStore.coordinate?.latitude) { _, _ in
            // LocationStore got a new fix — sync and re-sort
            userLocation = locationStore.coordinate
            locationName = locationStore.cityName
            viewModel.updateLocation(locationStore.coordinate)
        }
        .onChange(of: userLocation?.latitude) { _, _ in
            viewModel.updateLocation(userLocation)
        }
        .navigationDestination(item: $bookingContext) { ctx in
            BookingFlowView(context: ctx)
        }
    }
}

// MARK: - ArtistSearchResultCard

private struct ArtistSearchResultCard: View {
    let item: ArtistWithAvailability
    var matchedService: MatchedService? = nil

    // ...existing code...

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ...existing code... (Cover, badges, avatar)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.artist.artistName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .padding(.top, 24)

                if let spec = item.artist.specialties?.first {
                    Text(spec)
                        .font(.caption)
                        .foregroundStyle(Color.piumsOrange)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                if let rating = item.artist.averageRating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2).foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption.bold())
                        Text("(\(item.artist.totalReviews))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                // Price — matched service (SmartSearch) overrides main service
                let displayPrice = matchedService?.price ?? item.mainServicePrice
                let displayName  = matchedService?.name ?? item.mainServiceName
                if let price = displayPrice, price > 0 {
                    HStack {
                        if let svcName = displayName {
                            Text(svcName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            if matchedService != nil {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.piumsOrange)
                            }
                            Text(price.piumsFormatted)
                                .font(.caption.bold()).foregroundStyle(Color.piumsOrange)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.piumsOrange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Reservar button
                Text("Reservar")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(item.available ? Color.piumsOrange : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
        .opacity(item.available ? 1.0 : 0.65)
    }
}

// MARK: - BookingFlowContext Hashable (needed for navigationDestination)
extension BookingFlowContext: Hashable {
    static func == (lhs: BookingFlowContext, rhs: BookingFlowContext) -> Bool { lhs.artist.id == rhs.artist.id }
    func hash(into hasher: inout Hasher) { hasher.combine(artist.id) }
}
