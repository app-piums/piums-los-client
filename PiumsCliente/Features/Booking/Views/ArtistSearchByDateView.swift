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
    var artists: [ArtistWithAvailability] = []
    var isLoading = false
    var errorMessage: String?
    var showOnlyAvailable = true
    var categoryFilter: String?
    var searchQuery = ""

    var displayed: [ArtistWithAvailability] {
        artists.filter { item in
            if showOnlyAvailable && !item.available { return false }
            if let cat = categoryFilter {
                let sp = item.artist.specialties?.joined(separator: " ").lowercased() ?? ""
                if !sp.contains(cat.lowercased()) { return false }
            }
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let name = item.artist.artistName.lowercased()
                let city = (item.artist.city ?? "").lowercased()
                let specs = (item.artist.specialties ?? []).joined(separator: " ").lowercased()
                if !name.contains(q) && !city.contains(q) && !specs.contains(q) { return false }
            }
            return true
        }
    }

    func load(date: Date, location: CLLocationCoordinate2D?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let dateStr = isoDate(date)
            let cal = Calendar.current
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)

            // 1. Obtener todos los artistas
            let searchRes: SearchArtistsResponse = try await APIClient.request(
                .searchArtists(q: nil, page: 1, limit: 60, specialty: nil, city: nil,
                               minPrice: nil, maxPrice: nil, minRating: nil,
                               isVerified: nil, sortBy: nil, sortOrder: nil)
            )
            let rawArtists = searchRes.artists

            // 2. Batch check calendarios en paralelo
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

            // 3. Enriquecer con disponibilidad + distancia
            let enriched: [ArtistWithAvailability] = rawArtists.map { artist in
                let cal = calendars[artist.id]
                let available = cal == nil ||
                    (!cal!.occupiedDates.contains(dateStr) && !cal!.blockedDates.contains(dateStr))

                var distance: Double? = nil
                if let loc = location {
                    let cityKey = artist.city ?? ""
                    let coords = CITY_COORDS[cityKey]
                    let lat = coords?.0
                    let lng = coords?.1
                    if let lat = lat, let lng = lng {
                        distance = haversineKm(loc.latitude, loc.longitude, lat, lng)
                    }
                }

                return ArtistWithAvailability(
                    artist: artist,
                    available: available,
                    distance: distance,
                    mainServicePrice: artist.mainServicePrice,
                    mainServiceName: artist.mainServiceName
                )
            }

            // 4. Sort: disponibles primero, luego por distancia asc (nulos al final)
            artists = enriched.sorted { a, b in
                if a.available != b.available { return a.available && !b.available }
                switch (a.distance, b.distance) {
                case let (d1?, d2?): return d1 < d2
                case (_?, nil):      return true
                default:             return false
                }
            }

        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
}

// MARK: - View

struct ArtistSearchByDateView: View {
    let selectedDate: Date
    let userLocation: CLLocationCoordinate2D?
    let locationName: String

    @State private var viewModel = ArtistSearchByDateViewModel()
    @State private var selectedArtist: Artist?
    @State private var bookingContext: BookingFlowContext?

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: selectedDate).capitalized
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header fecha + ubicación
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.piumsOrange)
                        Text(dateLabel)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if !locationName.isEmpty && locationName != "Ubicación no disponible" {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.piumsOrange)
                                Text(locationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Filtros rápidos
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Disponibles toggle
                            Toggle("Solo disponibles", isOn: $viewModel.showOnlyAvailable)
                                .toggleStyle(.button)
                                .font(.caption.weight(.semibold))
                                .tint(.green)
                                .padding(.horizontal, 4)

                            // Search input
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
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 14)
                .background(.bar)

                Divider()

                // Results header
                if !viewModel.isLoading {
                    HStack {
                        Text("\(viewModel.displayed.count) artista(s) encontrado(s)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if userLocation == nil {
                            Label("Agrega ubicación para ordenar por distancia", systemImage: "info.circle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
                    // Grid 2 cols
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(viewModel.displayed) { item in
                            ArtistSearchResultCard(item: item)
                                .onTapGesture {
                                    bookingContext = BookingFlowContext(
                                        artist: item.artist,
                                        selectedDate: selectedDate
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
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task { await viewModel.load(date: selectedDate, location: userLocation) }
        .navigationDestination(item: $bookingContext) { ctx in
            BookingFlowView(context: ctx)
        }
    }
}

// MARK: - ArtistSearchResultCard

private struct ArtistSearchResultCard: View {
    let item: ArtistWithAvailability

    private static let gradients: [[Color]] = [
        [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.96, green: 0.36, blue: 0.55)],
        [Color(red: 0.36, green: 0.55, blue: 0.96), Color(red: 0.96, green: 0.55, blue: 0.36)],
        [Color(red: 0.70, green: 0.30, blue: 0.90), Color(red: 0.90, green: 0.50, blue: 0.70)],
        [Color(red: 0.40, green: 0.60, blue: 0.90), Color(red: 0.80, green: 0.40, blue: 0.90)],
    ]
    private var gradient: [Color] {
        Self.gradients[abs(item.artist.id.hashValue) % Self.gradients.count]
    }
    private var initials: String {
        item.artist.artistName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0) } }.joined().uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 110)

                // Disponibilidad badge top-right
                HStack {
                    Spacer()
                    Label(item.available ? "Disponible" : "Ocupado",
                          systemImage: item.available ? "circle.fill" : "circle")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(item.available ? Color.green : Color.gray)
                        .clipShape(Capsule())
                        .padding(8)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                // Distancia badge top-left
                if let km = item.distance {
                    Text(km < 1 ? "< 1 km" : String(format: "%.0f km", km))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Avatar iniciales
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red:0.85,green:0.30,blue:0.50),
                                                      Color(red:0.96,green:0.36,blue:0.36)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    Text(initials).font(.caption.bold()).foregroundStyle(.white)
                }
                .offset(x: 12, y: 19)
            }
            .frame(height: 110)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))

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

                if let price = item.mainServicePrice, price > 0 {
                    HStack {
                        if let svcName = item.mainServiceName {
                            Text(svcName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(price.piumsFormatted)
                            .font(.caption.bold()).foregroundStyle(Color.piumsOrange)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.piumsOrange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Botón Reservar
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
        .background(Color(.secondarySystemBackground))
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
