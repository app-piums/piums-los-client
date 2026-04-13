// Models.swift — modelos de dominio mapeados al shape REAL del backend Piums
import Foundation

// MARK: - Helpers

/// Respuesta vacía o irrelevante del backend
struct VoidResponse: Codable {}

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
    // Coordenadas exactas del artista (cuando el backend las devuelve)
    let baseLocationLat: Double?
    let baseLocationLng: Double?

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

// MARK: - SmartSearch Response  (shape: /api/search/smart)

struct MatchedService: Codable {
    let id: String
    let name: String
    let price: Int
    let currency: String
    let pricingType: String?
    let isExactMatch: Bool?
}

struct SmartArtist: Codable, Identifiable {
    let id: String
    let name: String
    let bio: String?
    let city: String?
    let state: String?
    let country: String?
    let averageRating: Double?
    let totalReviews: Int
    let totalBookings: Int
    let hourlyRateMin: Int?
    let hourlyRateMax: Int?
    let mainServicePrice: Int?
    let mainServiceName: String?
    let isVerified: Bool
    let isActive: Bool
    let isAvailable: Bool
    let servicesCount: Int
    let serviceIds: [String]?
    let serviceTitles: [String]?
    let specialties: [String]?
    let matchedService: MatchedService?
    let score: Double?
    let createdAt: String?
    // Coordenadas exactas
    let baseLocationLat: Double?
    let baseLocationLng: Double?

    /// Convierte a Artist para reutilizar las vistas existentes
    func toArtist() -> Artist {
        Artist(id: id, name: name, bio: bio, city: city, state: state, country: country,
               averageRating: averageRating, totalReviews: totalReviews, totalBookings: totalBookings,
               hourlyRateMin: hourlyRateMin, hourlyRateMax: hourlyRateMax,
               mainServicePrice: matchedService?.price ?? mainServicePrice,
               mainServiceName: matchedService?.name ?? mainServiceName,
               isVerified: isVerified, isActive: isActive, isAvailable: isAvailable,
               servicesCount: servicesCount, serviceIds: serviceIds, serviceTitles: serviceTitles,
               specialties: specialties, createdAt: createdAt,
               baseLocationLat: baseLocationLat, baseLocationLng: baseLocationLng)
    }
}

struct SmartSearchResponse: Codable {
    let artists: [SmartArtist]
    let expandedTerms: [String]?
    let totalFound: Int?
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

// MARK: - Notification  (shape real: GET /api/notifications)

struct PiumsNotification: Codable, Identifiable {
    let id: String
    let title: String
    let message: String         // backend usa "message" no "body"
    let type: String
    let readAt: String?         // null = no leída, fecha ISO = leída
    let data: NotificationData?
    let createdAt: String

    // Computed helpers
    var isRead: Bool { readAt != nil }
    var body: String { message }
}

struct NotificationData: Codable {
    let bookingId: String?
    let artistId: String?
    let reviewId: String?
    let rating: Int?
    let disputeId: String?
    let amount: Double?

    // Soporte para claves extra del backend
    private enum CodingKeys: String, CodingKey {
        case bookingId, artistId, reviewId, rating, disputeId, amount
    }
}

// MARK: - Notifications Response

struct NotificationsResponse: Codable {
    let notifications: [PiumsNotification]
    let pagination: NotificationsPagination

    struct NotificationsPagination: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let pages: Int         // backend usa "pages" no "totalPages"

        var hasMore: Bool { page < pages }
    }
}

// MARK: - Pagination genérica (para endpoints que sí devuelven este shape)

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let total: Int
    let page: Int
    let totalPages: Int
    let hasMore: Bool
}

// MARK: - Dispute  (shape: GET /api/disputes/me → {asReporter:[], asReported:[], total:0})

struct Dispute: Codable, Identifiable, Hashable {
    let id: String
    let bookingId: String
    let reportedBy: String
    let reportedAgainst: String?
    let disputeType: String
    let subject: String
    let description: String
    let status: DisputeStatus
    let priority: Int?
    let resolution: String?
    let resolutionNotes: String?
    let refundAmount: Double?
    let createdAt: String
    let updatedAt: String?
    let messages: [DisputeMessage]?

    // Computed property for backward compatibility
    var type: String { disputeType }

    static func == (lhs: Dispute, rhs: Dispute) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DisputeStatus: String, Codable {
    case open        = "OPEN"
    case inReview    = "IN_REVIEW"
    case awaitingInfo = "AWAITING_INFO"
    case resolved    = "RESOLVED"
    case closed      = "CLOSED"
    case escalated   = "ESCALATED"

    var displayName: String {
        switch self {
        case .open:         return "Abierta"
        case .inReview:     return "En revisión"
        case .awaitingInfo: return "Esperando info"
        case .resolved:     return "Resuelta"
        case .closed:       return "Cerrada"
        case .escalated:    return "Escalada"
        }
    }

    var color: String {
        switch self {
        case .open:         return "orange"
        case .inReview:     return "blue"
        case .awaitingInfo: return "yellow"
        case .resolved:     return "green"
        case .closed:       return "gray"
        case .escalated:    return "red"
        }
    }
}

struct DisputeMessage: Codable, Identifiable {
    let id: String
    let disputeId: String
    let senderId: String
    let senderType: String
    let message: String
    let isStatusUpdate: Bool?
    let oldStatus: String?
    let newStatus: String?
    let createdAt: String

    // Computed property for backward compatibility
    var senderRole: String { senderType }
}

struct DisputesResponse: Codable {
    let asReporter: [Dispute]
    let asReported: [Dispute]
    let total: Int

    var allDisputes: [Dispute] {
        (asReporter + asReported).sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Events (booking-service)

struct EventSummary: Codable, Identifiable, Hashable {
    let id: String
    let code: String
    let clientId: String
    let name: String
    let description: String?
    let location: String?
    let notes: String?
    let eventDate: String?
    let status: EventStatus
    let createdAt: String
    let updatedAt: String?
    let bookings: [EventBooking]?

    static func == (lhs: EventSummary, rhs: EventSummary) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct EventBooking: Codable, Identifiable, Hashable {
    let id: String
    let code: String?
    let artistId: String
    let serviceId: String
    let scheduledDate: String
    let status: BookingStatus
    let totalPrice: Int
    let currency: String?

    static func == (lhs: EventBooking, rhs: EventBooking) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum EventStatus: String, Codable {
    case draft = "DRAFT"
    case active = "ACTIVE"
    case cancelled = "CANCELLED"
}

struct EventsResponse: Codable {
    let success: Bool
    let data: [EventSummary]
}

struct EventResponse: Codable {
    let success: Bool
    let data: EventSummary
}

// MARK: - Chat (chat-service)

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let artistId: String
    let bookingId: String?
    let status: String
    let lastMessageAt: String?
    let createdAt: String
    let updatedAt: String
    let unreadCount: Int?
    let messages: [ChatMessage]?

    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderType: String
    let content: String
    let type: String
    let read: Bool
    let readAt: String?          // backend usa readAt, no always present
    let createdAt: String
    let updatedAt: String?       // optional — backend may omit it

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ConversationsResponse: Codable {
    let conversations: [Conversation]
    let total: Int
    let page: Int
    let totalPages: Int
}

struct MessagesResponse: Codable {
    let messages: [ChatMessage]
    let total: Int
    let page: Int
    let totalPages: Int
}

struct ConversationWrapper: Codable {
    let conversation: Conversation
}

struct MessageWrapper: Codable {
    let message: ChatMessage
}

struct UnreadCountResponse: Codable {
    let unreadCount: Int
}

// MARK: - Mock helpers

extension Artist {
    static var mock: Artist {
        Artist(id: "1", name: "Carlos Méndez", bio: "Guitarrista profesional.", city: "Ciudad de Guatemala",
               state: nil, country: "GT", averageRating: 4.8, totalReviews: 32, totalBookings: 5,
               hourlyRateMin: 15000, hourlyRateMax: 30000, mainServicePrice: 15000,
               mainServiceName: "Show 1 hora", isVerified: true, isActive: true, isAvailable: true,
               servicesCount: 2, serviceIds: nil, serviceTitles: nil, specialties: ["Guitarra", "Eventos"],
               createdAt: nil, baseLocationLat: nil, baseLocationLng: nil)
    }

    static var mockList: [Artist] {
        [
            Artist(id: "1", name: "Carlos Méndez", bio: nil, city: "Ciudad de Guatemala", state: nil, country: "GT", averageRating: 4.8, totalReviews: 32, totalBookings: 5, hourlyRateMin: 15000, hourlyRateMax: 30000, mainServicePrice: 15000, mainServiceName: "Show 1h", isVerified: true, isActive: true, isAvailable: true, servicesCount: 2, serviceIds: nil, serviceTitles: nil, specialties: ["Guitarra"], createdAt: nil, baseLocationLat: nil, baseLocationLng: nil),
            Artist(id: "2", name: "Sofía Ramírez", bio: nil, city: "Antigua", state: nil, country: "GT", averageRating: 4.5, totalReviews: 18, totalBookings: 10, hourlyRateMin: 20000, hourlyRateMax: 40000, mainServicePrice: 20000, mainServiceName: "Show 1h", isVerified: true, isActive: true, isAvailable: true, servicesCount: 3, serviceIds: nil, serviceTitles: nil, specialties: ["Baile"], createdAt: nil, baseLocationLat: nil, baseLocationLng: nil),
            Artist(id: "3", name: "Javier Torres", bio: nil, city: "Quetzaltenango", state: nil, country: "GT", averageRating: 4.9, totalReviews: 55, totalBookings: 20, hourlyRateMin: 25000, hourlyRateMax: 50000, mainServicePrice: 25000, mainServiceName: "Sesión foto", isVerified: false, isActive: true, isAvailable: true, servicesCount: 4, serviceIds: nil, serviceTitles: nil, specialties: ["Fotografía"], createdAt: nil, baseLocationLat: nil, baseLocationLng: nil),
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
            PiumsNotification(id: "n1", title: "Reserva confirmada", message: "Tu reserva PMS-001 fue confirmada.", type: "BOOKING_CONFIRMED", readAt: nil, data: NotificationData(bookingId: "b1", artistId: nil, reviewId: nil, rating: nil, disputeId: nil, amount: nil), createdAt: "2026-04-09T10:00:00Z"),
            PiumsNotification(id: "n2", title: "Pago recibido", message: "El artista recibió tu pago.", type: "PAYMENT_COMPLETED", readAt: "2026-04-08T15:00:00Z", data: nil, createdAt: "2026-04-08T15:00:00Z")
        ]
    }
}

// MARK: - Favorites (users-service)

struct FavoriteRecord: Codable, Identifiable, Hashable {
    let id: String
    let entityType: String
    let entityId: String
    let notes: String?
    let createdAt: String
    let deletedAt: String?

    static func == (lhs: FavoriteRecord, rhs: FavoriteRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct FavoritesResponse: Codable {
    let data: [FavoriteRecord]
    let total: Int
    let page: Int
    let totalPages: Int
}

struct FavoriteCheckResponse: Codable {
    let isFavorite: Bool
    let favoriteId: String?
}

// MARK: - Booking Flow Models

/// Slot de disponibilidad horaria  (GET /api/availability/time-slots)
struct TimeSlot: Codable, Identifiable {
    var id: String { time }
    let time: String          // "09:00"
    let available: Bool
    let startTime: String?    // ISO
    let endTime: String?      // ISO
}

struct TimeSlotsResponse: Codable {
    let artistId: String?
    let date: String?
    let slots: [TimeSlot]
}

/// Calendario de ocupación  (GET /api/availability/calendar)
struct ArtistCalendar: Codable {
    let artistId: String?
    let year: Int?
    let month: Int?
    let occupiedDates: [String]   // ["2026-04-07", ...]
    let blockedDates: [String]
}

/// Ítem de cotización de precio
struct PriceQuoteItem: Codable {
    let type: String          // "BASE" | "ADDON" | "TRAVEL"
    let name: String
    let qty: Int?
    let unitPriceCents: Int?
    let totalPriceCents: Int
    let metadata: PriceQuoteItemMeta?
}

struct PriceQuoteItemMeta: Codable {
    let distanceKm: Double?
    let clientLat: Double?
    let clientLng: Double?
}

struct PriceQuoteBreakdown: Codable {
    let baseCents: Int
    let addonsCents: Int
    let travelCents: Int
    let discountsCents: Int?
}

/// Cotización completa  (POST /api/catalog/pricing/calculate)
struct PriceQuote: Codable {
    let serviceId: String?
    let currency: String
    let items: [PriceQuoteItem]
    let subtotalCents: Int
    let totalCents: Int
    let breakdown: PriceQuoteBreakdown?

    var totalInUnits: Double  { Double(totalCents) / 100.0 }
    var baseInUnits: Double   { Double(breakdown?.baseCents ?? 0) / 100.0 }
    var travelInUnits: Double { Double(breakdown?.travelCents ?? 0) / 100.0 }
    var hasTravel: Bool       { (breakdown?.travelCents ?? 0) > 0 }
}

/// Contexto que fluye entre los pasos de reserva
struct BookingFlowContext {
    var artist: Artist
    var service: ArtistService?
    var selectedDate: Date?
    var selectedSlot: TimeSlot?
    var isMultiDay: Bool = false
    var numDays: Int = 1
    var location: String = ""
    var locationLat: Double?
    var locationLng: Double?
    var clientNotes: String = ""
    var priceQuote: PriceQuote?
    var eventId: String? = nil  // NEW: asociar reserva a un evento

    /// Fecha en formato ISO requerido por el backend: "2026-04-28T10:00:00.000Z"
    var scheduledDateISO: String? {
        guard let date = selectedDate, let slot = selectedSlot else { return nil }
        let cal = Calendar.current
        let comps = slot.time.split(separator: ":").compactMap { Int($0) }
        guard comps.count == 2 else { return nil }
        var dc = cal.dateComponents([.year, .month, .day], from: date)
        dc.hour = comps[0]; dc.minute = comps[1]; dc.second = 0
        guard let combined = cal.date(from: dc) else { return nil }
        return ISO8601DateFormatter().string(from: combined)
    }

    var durationMinutes: Int {
        if isMultiDay { return numDays * 24 * 60 }
        return service?.durationMin ?? service?.durationMax ?? 60
    }
}

