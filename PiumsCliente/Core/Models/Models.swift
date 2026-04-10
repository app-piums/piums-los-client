// Models.swift — modelos de dominio mapeados al shape REAL del backend Piums
import Foundation

// MARK: - Auth

struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String
    let nombre: String?
    let role: String      // "cliente" | "artista" | "admin"
    let avatar: String?

    var avatarUrl: String? { avatar }
    var displayName: String { nombre ?? email }
}

// MARK: - Artist  (shape: GET /api/search/artists)

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let bio: String?
    let city: String?
    let state: String?
    let country: String?
    let averageRating: Double?
    let totalReviews: Int
    let totalBookings: Int
    let hourlyRateMin: Int?    // en centavos/unidades
    let hourlyRateMax: Int?
    let mainServicePrice: Int? // precio del servicio principal
    let mainServiceName: String?
    let isVerified: Bool
    let isActive: Bool
    let isAvailable: Bool
    let servicesCount: Int
    let serviceIds: [String]?
    let serviceTitles: [String]?
    let specialties: [String]?
    let createdAt: String?

    // Computed helpers para la UI
    var artistName: String { name }
    var avatarUrl: String? { nil }   // el backend no devuelve avatar en search
    var rating: Double? { averageRating }
    var reviewsCount: Int { totalReviews }
    var basePrice: Int? { mainServicePrice }

    // Hashable
    static func == (lhs: Artist, rhs: Artist) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Search Response  (shape: /api/search/artists)

struct SearchArtistsResponse: Codable {
    let artists: [Artist]
    let pagination: SearchPagination
}

struct SearchPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    var hasMore: Bool { page < totalPages }
}

// MARK: - ArtistCategory (categorías locales para filtros UI — no vienen del backend en search)

enum ArtistCategory: String, Codable, CaseIterable {
    case musico       = "MUSICO"
    case bailarin     = "BAILARIN"
    case fotografo    = "FOTOGRAFO"
    case videografo   = "VIDEOGRAFO"
    case disenador    = "DISENADOR"
    case escritor     = "ESCRITOR"
    case animador     = "ANIMADOR"
    case mago         = "MAGO"
    case acrobata     = "ACROBATA"
    case actor        = "ACTOR"
    case comediante   = "COMEDIANTE"
    case artePlastico = "ARTE_PLASTICO"
    case dj           = "DJ"
    case chef         = "CHEF"
    case yoga         = "YOGA"

    var displayName: String {
        switch self {
        case .musico:       return "Músico"
        case .bailarin:     return "Bailarín"
        case .fotografo:    return "Fotógrafo"
        case .videografo:   return "Videógrafo"
        case .disenador:    return "Diseñador"
        case .escritor:     return "Escritor"
        case .animador:     return "Animador"
        case .mago:         return "Mago"
        case .acrobata:     return "Acróbata"
        case .actor:        return "Actor"
        case .comediante:   return "Comediante"
        case .artePlastico: return "Arte Plástico"
        case .dj:           return "DJ"
        case .chef:         return "Chef"
        case .yoga:         return "Yoga"
        }
    }

    var systemImage: String {
        switch self {
        case .musico:       return "music.note"
        case .bailarin:     return "figure.dance"
        case .fotografo:    return "camera"
        case .videografo:   return "video"
        case .disenador:    return "paintbrush"
        case .escritor:     return "pencil"
        case .animador:     return "face.smiling"
        case .mago:         return "wand.and.stars"
        case .acrobata:     return "figure.gymnastics"
        case .actor:        return "theatermasks"
        case .comediante:   return "mic"
        case .artePlastico: return "paintpalette"
        case .dj:           return "headphones"
        case .chef:         return "fork.knife"
        case .yoga:         return "figure.mind.and.body"
        }
    }
}

// MARK: - ArtistService  (shape: GET /api/catalog/services?artistId=)

struct ArtistService: Codable, Identifiable, Hashable {
    let id: String
    let artistId: String
    let name: String
    let description: String?
    let pricingType: String?   // "FIXED" | "HOURLY" | "PACKAGE"
    let basePrice: Int         // en centavos/unidades
    let currency: String
    let durationMin: Int?
    let durationMax: Int?
    let status: String?        // "ACTIVE" | "INACTIVE"
    let isAvailable: Bool?
    let isFeatured: Bool?
    let whatIsIncluded: [String]?
    let thumbnail: String?
    let tags: [String]?
    let isMainService: Bool?
    let createdAt: String?

    // Helpers para UI
    var price: Int { basePrice }
    var duration: Int { durationMin ?? 60 }
    var isActive: Bool { status == "ACTIVE" }
    var category: String? { nil }

    // Hashable
    static func == (lhs: ArtistService, rhs: ArtistService) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Catalog Services Response

struct CatalogServicesResponse: Codable {
    let services: [ArtistService]
}

// MARK: - Booking  (shape: GET /api/bookings)

struct Booking: Codable, Identifiable, Hashable {
    let id: String
    let code: String?
    let clientId: String
    let artistId: String
    let serviceId: String
    let status: BookingStatus
    let paymentStatus: PaymentStatus
    let totalPrice: Int
    let scheduledDate: String
    let scheduledTime: String?
    let duration: Int?
    let notes: String?
    let location: String?
    let createdAt: String

    // Hashable
    static func == (lhs: Booking, rhs: Booking) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - BookingStatus / PaymentStatus

enum BookingStatus: String, Codable {
    case pending           = "PENDING"
    case confirmed         = "CONFIRMED"
    case paymentPending    = "PAYMENT_PENDING"
    case paymentCompleted  = "PAYMENT_COMPLETED"
    case inProgress        = "IN_PROGRESS"
    case completed         = "COMPLETED"
    case rescheduled       = "RESCHEDULED"
    case cancelledClient   = "CANCELLED_CLIENT"
    case cancelledArtist   = "CANCELLED_ARTIST"
    case rejected          = "REJECTED"
    case noShow            = "NO_SHOW"

    var displayName: String {
        switch self {
        case .pending:          return "Pendiente"
        case .confirmed:        return "Confirmada"
        case .paymentPending:   return "Pago pendiente"
        case .paymentCompleted: return "Pago completado"
        case .inProgress:       return "En progreso"
        case .completed:        return "Completada"
        case .rescheduled:      return "Reprogramada"
        case .cancelledClient:  return "Cancelada por ti"
        case .cancelledArtist:  return "Cancelada por artista"
        case .rejected:         return "Rechazada"
        case .noShow:           return "No se presentó"
        }
    }
}

enum PaymentStatus: String, Codable {
    case pending   = "PENDING"
    case completed = "COMPLETED"
    case refunded  = "REFUNDED"
    case failed    = "FAILED"
}

// MARK: - Bookings Paginated Response

struct BookingsResponse: Codable {
    let bookings: [Booking]
    let pagination: SearchPagination?
    // fallback si el backend devuelve shape diferente
    let data: [Booking]?
    let total: Int?
    let page: Int?
    let totalPages: Int?

    var allBookings: [Booking] { bookings.isEmpty ? (data ?? []) : bookings }
    var hasMore: Bool {
        if let pag = pagination { return pag.hasMore }
        guard let p = page, let tp = totalPages else { return false }
        return p < tp
    }
}

// MARK: - Review  (shape: GET /api/reviews?artistId=)

struct Review: Codable, Identifiable {
    let id: String
    let artistId: String
    let clientId: String
    let bookingId: String
    let rating: Int
    let comment: String?
    let createdAt: String
    // campos adicionales que puede mandar el backend
    let clientName: String?
    let clientAvatar: String?
}

// MARK: - Reviews Response

struct ReviewsResponse: Codable {
    let reviews: [Review]
    let pagination: SearchPagination?
    let data: [Review]?

    var allReviews: [Review] { reviews.isEmpty ? (data ?? []) : reviews }
    var hasMore: Bool { pagination?.hasMore ?? false }
}

// MARK: - Notification

struct PiumsNotification: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let type: String
    let isRead: Bool
    let data: [String: String]?
    let createdAt: String
}

// MARK: - Pagination genérica (para endpoints que sí devuelven este shape)

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let total: Int
    let page: Int
    let totalPages: Int
    let hasMore: Bool
}

// MARK: - Mock helpers

extension Artist {
    static var mock: Artist {
        Artist(id: "1", name: "Carlos Méndez", bio: "Guitarrista profesional.", city: "Ciudad de Guatemala",
               state: nil, country: "GT", averageRating: 4.8, totalReviews: 32, totalBookings: 5,
               hourlyRateMin: 15000, hourlyRateMax: 30000, mainServicePrice: 15000,
               mainServiceName: "Show 1 hora", isVerified: true, isActive: true, isAvailable: true,
               servicesCount: 2, serviceIds: nil, serviceTitles: nil, specialties: ["Guitarra", "Eventos"],
               createdAt: nil)
    }

    static var mockList: [Artist] {
        [
            Artist(id: "1", name: "Carlos Méndez", bio: nil, city: "Ciudad de Guatemala", state: nil, country: "GT", averageRating: 4.8, totalReviews: 32, totalBookings: 5, hourlyRateMin: 15000, hourlyRateMax: 30000, mainServicePrice: 15000, mainServiceName: "Show 1h", isVerified: true, isActive: true, isAvailable: true, servicesCount: 2, serviceIds: nil, serviceTitles: nil, specialties: ["Guitarra"], createdAt: nil),
            Artist(id: "2", name: "Sofía Ramírez", bio: nil, city: "Antigua", state: nil, country: "GT", averageRating: 4.5, totalReviews: 18, totalBookings: 10, hourlyRateMin: 20000, hourlyRateMax: 40000, mainServicePrice: 20000, mainServiceName: "Show 1h", isVerified: true, isActive: true, isAvailable: true, servicesCount: 3, serviceIds: nil, serviceTitles: nil, specialties: ["Baile"], createdAt: nil),
            Artist(id: "3", name: "Javier Torres", bio: nil, city: "Quetzaltenango", state: nil, country: "GT", averageRating: 4.9, totalReviews: 55, totalBookings: 20, hourlyRateMin: 25000, hourlyRateMax: 50000, mainServicePrice: 25000, mainServiceName: "Sesión foto", isVerified: false, isActive: true, isAvailable: true, servicesCount: 4, serviceIds: nil, serviceTitles: nil, specialties: ["Fotografía"], createdAt: nil),
        ]
    }
}

extension Booking {
    static var mock: Booking {
        Booking(id: "b1", code: "PMS-001", clientId: "c1", artistId: "1", serviceId: "s1",
                status: .confirmed, paymentStatus: .completed, totalPrice: 15000,
                scheduledDate: "2026-05-10", scheduledTime: "15:00", duration: 60,
                notes: nil, location: "Salón Principal", createdAt: "2026-04-09T10:00:00Z")
    }
}

extension ArtistService {
    static func mockList(artistId: String) -> [ArtistService] {
        [
            ArtistService(id: "s1", artistId: artistId, name: "Show 1 hora", description: "Presentación de 60 min.", pricingType: "FIXED", basePrice: 15000, currency: "GTQ", durationMin: 60, durationMax: 60, status: "ACTIVE", isAvailable: true, isFeatured: true, whatIsIncluded: ["Equipo de sonido", "1 hora de show"], thumbnail: nil, tags: nil, isMainService: true, createdAt: nil),
            ArtistService(id: "s2", artistId: artistId, name: "Show 30 min", description: "Mini presentación.", pricingType: "FIXED", basePrice: 9000, currency: "GTQ", durationMin: 30, durationMax: 30, status: "ACTIVE", isAvailable: true, isFeatured: false, whatIsIncluded: ["30 minutos de show"], thumbnail: nil, tags: nil, isMainService: false, createdAt: nil)
        ]
    }
}

extension Review {
    static func mockList(artistId: String) -> [Review] {
        [
            Review(id: "r1", artistId: artistId, clientId: "c1", bookingId: "b1", rating: 5, comment: "Excelente presentación.", createdAt: "2026-03-15T10:00:00Z", clientName: "María G.", clientAvatar: nil),
            Review(id: "r2", artistId: artistId, clientId: "c2", bookingId: "b2", rating: 4, comment: "Muy buen artista, puntual.", createdAt: "2026-02-20T14:00:00Z", clientName: "Juan P.", clientAvatar: nil)
        ]
    }
}

extension PiumsNotification {
    static var mockList: [PiumsNotification] {
        [
            PiumsNotification(id: "n1", title: "Reserva confirmada", body: "Tu reserva PMS-001 fue confirmada.", type: "BOOKING_CONFIRMED", isRead: false, data: nil, createdAt: "2026-04-09T10:00:00Z"),
            PiumsNotification(id: "n2", title: "Pago recibido", body: "El artista recibió tu pago.", type: "PAYMENT_COMPLETED", isRead: true, data: nil, createdAt: "2026-04-08T15:00:00Z")
        ]
    }
}
