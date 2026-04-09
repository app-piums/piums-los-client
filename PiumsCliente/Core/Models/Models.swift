// Models.swift — todos los modelos de dominio de Piums Cliente
import Foundation

// MARK: - Auth

struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String
    let nombre: String?
    let role: String      // "CLIENT" | "ARTIST" | "ADMIN"
    let avatarUrl: String?
}

// MARK: - Artist

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    let artistName: String
    let category: ArtistCategory
    let bio: String?
    let rating: Double?
    let reviewsCount: Int
    let basePrice: Int?
    let city: String?
    let avatarUrl: String?
    let isVerified: Bool
}

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

// MARK: - Service (Catalog)

struct ArtistService: Codable, Identifiable, Hashable {
    let id: String
    let artistId: String
    let name: String
    let description: String?
    let price: Int           // centavos
    let currency: String     // "USD" | "GTQ"
    let duration: Int        // minutos
    let category: String?
    let isActive: Bool
}

// MARK: - Booking

struct Booking: Codable, Identifiable, Hashable {
    let id: String
    let code: String?
    let clientId: String
    let artistId: String
    let serviceId: String
    let status: BookingStatus
    let paymentStatus: PaymentStatus
    let totalPrice: Int          // centavos
    let scheduledDate: String
    let scheduledTime: String?
    let duration: Int?           // minutos
    let notes: String?
    let location: String?
    let createdAt: String
}

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

// MARK: - Review

struct Review: Codable, Identifiable {
    let id: String
    let artistId: String
    let clientId: String
    let bookingId: String
    let rating: Int          // 1–5
    let comment: String?
    let createdAt: String
}

// MARK: - Event

struct Event: Codable, Identifiable {
    let id: String
    let code: String
    let name: String
    let description: String?
    let location: String?
    let notes: String?
    let eventDate: String?
    let status: EventStatus
    let bookings: [Booking]?
    let createdAt: String
}

enum EventStatus: String, Codable {
    case draft     = "DRAFT"
    case active    = "ACTIVE"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
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

// MARK: - Pagination

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
        Artist(
            id: "1",
            artistName: "Carlos Méndez",
            category: .musico,
            bio: "Guitarrista profesional con 10 años de experiencia.",
            rating: 4.8,
            reviewsCount: 32,
            basePrice: 15000,
            city: "Ciudad de Guatemala",
            avatarUrl: nil,
            isVerified: true
        )
    }

    static var mockList: [Artist] {
        [
            Artist(id: "1", artistName: "Carlos Méndez", category: .musico, bio: nil, rating: 4.8, reviewsCount: 32, basePrice: 15000, city: "Ciudad de Guatemala", avatarUrl: nil, isVerified: true),
            Artist(id: "2", artistName: "Sofía Ramírez", category: .bailarin, bio: nil, rating: 4.5, reviewsCount: 18, basePrice: 20000, city: "Antigua", avatarUrl: nil, isVerified: true),
            Artist(id: "3", artistName: "Javier Torres", category: .fotografo, bio: nil, rating: 4.9, reviewsCount: 55, basePrice: 25000, city: "Quetzaltenango", avatarUrl: nil, isVerified: false),
            Artist(id: "4", artistName: "Ana López", category: .dj, bio: nil, rating: 4.7, reviewsCount: 12, basePrice: 30000, city: "Ciudad de Guatemala", avatarUrl: nil, isVerified: true)
        ]
    }
}

extension Booking {
    static var mock: Booking {
        Booking(
            id: "b1",
            code: "PMS-001",
            clientId: "c1",
            artistId: "1",
            serviceId: "s1",
            status: .confirmed,
            paymentStatus: .completed,
            totalPrice: 15000,
            scheduledDate: "2026-05-10",
            scheduledTime: "15:00",
            duration: 60,
            notes: nil,
            location: "Salón Principal",
            createdAt: "2026-04-09T10:00:00Z"
        )
    }
}
