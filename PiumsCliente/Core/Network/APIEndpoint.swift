// APIEndpoint.swift
import Foundation

enum APIEndpoint {
    // ── Auth ──────────────────────────────────────────────
    case login(email: String, password: String)
    case registerClient(name: String, email: String, password: String)
    case firebaseAuth(token: String)
    case refreshToken(token: String)
    case logout
    case getMe                           // GET /api/auth/me
    case forgotPassword(email: String)

    // ── Artists ───────────────────────────────────────────
    case getArtist(id: String)
    case getArtistPortfolio(id: String)

    // ── Search ────────────────────────────────────────────
    case searchArtists(q: String?, page: Int, limit: Int, category: String?, cityId: String?)

    // ── Catalog ───────────────────────────────────────────
    case listServices(artistId: String)
    case getService(id: String)

    // ── Bookings ──────────────────────────────────────────
    case createBooking(payload: [String: Any])
    case listMyBookings(status: String?, page: Int)
    case getBooking(id: String)
    case cancelBooking(id: String)
    case getAvailableSlots(artistId: String, date: String)

    // ── Reviews ───────────────────────────────────────────
    case listReviews(artistId: String, page: Int)
    case createReview(payload: [String: Any])

    // ── Notifications ─────────────────────────────────────
    case listNotifications(page: Int)
    case markNotificationsRead(ids: [String])   // POST /api/notifications/read
    case registerPushToken(token: String, platform: String)

    // ── Disputes / Quejas ─────────────────────────────────
    case listMyDisputes
    case createDispute(payload: [String: Any])
    case getDispute(id: String)
    case addDisputeMessage(id: String, message: String)

    // ── Users / Profile ───────────────────────────────────
    case getMyProfile                                    // GET /api/auth/me
    case updateMyProfile(payload: [String: Any])         // PATCH /api/auth/profile
    case changePassword(current: String, new: String)    // POST /api/auth/change-password

    // ── Favorites ────────────────────────────────────────
    case listFavorites(page: Int, entityType: String)
    case addFavorite(entityType: String, entityId: String, notes: String?)
    case deleteFavorite(id: String)
    case checkFavorite(entityType: String, entityId: String)

    // ── Payments ──────────────────────────────────────────
    case createPaymentIntent(bookingId: String)
    case listPayments(page: Int)
    case getPayment(id: String)

    // ── Events ────────────────────────────────────────────
    case listEvents
    case createEvent(payload: [String: Any])
    case getEvent(id: String)
    case updateEvent(id: String, payload: [String: Any])
    case deleteEvent(id: String)

    // ── Chat ──────────────────────────────────────────────
    case listConversations(page: Int)
    case getConversation(id: String)
    case markConversationRead(id: String)
    case listMessages(conversationId: String, page: Int)
    case sendMessage(conversationId: String, content: String)
    case unreadCount

    // ── Onboarding ────────────────────────────────────────
    case completeOnboarding
}

extension APIEndpoint {
    private static var base: String {
        Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "http://localhost:3005"
    }

    var url: URL {
        URL(string: "\(Self.base)\(path)")!
    }

    var method: String {
        switch self {
        case .login, .registerClient, .firebaseAuth,
             .createBooking, .createReview, .createDispute, .addDisputeMessage,
             .markNotificationsRead, .registerPushToken, .forgotPassword,
             .logout, .createPaymentIntent,
             .createEvent, .sendMessage, .addFavorite:
            return "POST"
        case .cancelBooking:
            return "POST"
        case .updateMyProfile, .completeOnboarding, .updateEvent, .markConversationRead:
            return "PATCH"
        case .changePassword:
            return "POST"
        case .deleteEvent, .deleteFavorite:
            return "DELETE"
        default:
            return "GET"
        }
    }

    var body: Data? {
        switch self {
        case .login(let e, let p):
            return encode(["email": e, "password": p])
        case .registerClient(let n, let e, let p):
            return encode(["nombre": n, "email": e, "password": p])
        case .firebaseAuth(let t):
            return encode(["idToken": t, "role": "cliente"])
        case .refreshToken(let t):
            return encode(["refreshToken": t])
        case .forgotPassword(let e):
            return encode(["email": e])
        case .createBooking(let p), .createReview(let p), .createDispute(let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .addDisputeMessage(_, let msg):
            return encode(["message": msg])
        case .updateMyProfile(let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .markNotificationsRead(let ids):
            return encode(["notificationIds": ids])
        case .registerPushToken(let t, let pl):
            return encode(["token": t, "platform": pl])
        case .changePassword(let cur, let new):
            return encode(["currentPassword": cur, "newPassword": new])
        case .createPaymentIntent(let bId):
            return encode(["bookingId": bId])
        case .createEvent(let p), .updateEvent(_, let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .sendMessage(let conversationId, let content):
            return try? JSONSerialization.data(withJSONObject: [
                "conversationId": conversationId,
                "content": content,
                "type": "text"
            ])
        case .addFavorite(let entityType, let entityId, let notes):
            var payload: [String: Any] = ["entityType": entityType, "entityId": entityId]
            if let notes { payload["notes"] = notes }
            return try? JSONSerialization.data(withJSONObject: payload)
        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .registerClient, .firebaseAuth, .forgotPassword,
             .searchArtists, .getArtist, .listReviews, .getArtistPortfolio:
            return false
        default:
            return true
        }
    }

    private var path: String {
        switch self {
        // Auth
        case .login:                           return "/api/auth/login"
        case .registerClient:                  return "/api/auth/register/client"
        case .firebaseAuth:                    return "/api/auth/firebase"
        case .refreshToken:                    return "/api/auth/refresh"
        case .logout:                          return "/api/auth/logout"
        case .getMe:                           return "/api/auth/me"
        case .forgotPassword:                  return "/api/auth/forgot-password"

        // Artists
        case .getArtist(let id):               return "/api/artists/\(id)"
        case .getArtistPortfolio(let id):      return "/api/artists/\(id)/portfolio"

        // Search
        case .searchArtists(let q, let pg, let lm, let cat, let city):
            var p = "/api/search/artists?page=\(pg)&limit=\(lm)"
            if let q = q, !q.isEmpty { p += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)" }
            if let cat  = cat  { p += "&specialty=\(cat)" }
            if let city = city { p += "&city=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)" }
            return p

        // Catalog
        case .listServices(let artistId):      return "/api/catalog/services?artistId=\(artistId)"
        case .getService(let id):              return "/api/catalog/services/\(id)"

        // Bookings
        case .createBooking:                   return "/api/bookings"
        case .listMyBookings(let s, let pg):
            var p = "/api/bookings?page=\(pg)&limit=20"
            if let s = s { p += "&status=\(s)" }
            return p
        case .getBooking(let id):              return "/api/bookings/\(id)"
        case .cancelBooking(let id):           return "/api/bookings/\(id)/cancel"
        case .getAvailableSlots(let a, let d): return "/api/availability/time-slots?artistId=\(a)&date=\(d)"

        // Reviews — path directo (el service monta en /api/reviews internamente)
        case .listReviews(let a, let pg):      return "/api/reviews?artistId=\(a)&page=\(pg)&limit=10"
        case .createReview:                    return "/api/reviews"

        // Notifications
        case .listNotifications(let pg):       return "/api/notifications?page=\(pg)&limit=20"
        case .markNotificationsRead:           return "/api/notifications/read"
        case .registerPushToken:               return "/api/notifications/push-token"

        // Disputes
        case .listMyDisputes:                  return "/api/disputes/me"
        case .createDispute:                   return "/api/disputes"
        case .getDispute(let id):              return "/api/disputes/\(id)"
        case .addDisputeMessage(let id, _):    return "/api/disputes/\(id)/messages"

        // Users / Profile — todo via auth-service (mismo JWT)
        case .getMyProfile:                    return "/api/auth/me"
        case .updateMyProfile:                 return "/api/auth/profile"
        case .changePassword:                  return "/api/auth/change-password"

        // Favorites
        case .listFavorites(let pg, let type):
            return "/api/users/me/favorites?page=\(pg)&limit=50&entityType=\(type)"
        case .addFavorite:
            return "/api/users/me/favorites"
        case .deleteFavorite(let id):
            return "/api/users/me/favorites/\(id)"
        case .checkFavorite(let type, let entityId):
            return "/api/users/me/favorites/check?entityType=\(type)&entityId=\(entityId)"

        // Payments
        case .createPaymentIntent:             return "/api/payments/intent"
        case .listPayments(let pg):            return "/api/payments?page=\(pg)&limit=20"
        case .getPayment(let id):              return "/api/payments/\(id)"

        // Events
        case .listEvents:                      return "/api/events"
        case .createEvent:                     return "/api/events"
        case .getEvent(let id):                return "/api/events/\(id)"
        case .updateEvent(let id, _):          return "/api/events/\(id)"
        case .deleteEvent(let id):             return "/api/events/\(id)"

        // Chat
        case .listConversations(let pg):       return "/api/chat/conversations?page=\(pg)&limit=20"
        case .getConversation(let id):         return "/api/chat/conversations/\(id)"
        case .markConversationRead(let id):    return "/api/chat/conversations/\(id)/read"
        case .listMessages(let cid, let pg):   return "/api/chat/messages/\(cid)?page=\(pg)&limit=50"
        case .sendMessage:                     return "/api/chat/messages"
        case .unreadCount:                     return "/api/chat/messages/unread-count"

        // Onboarding
        case .completeOnboarding:              return "/api/auth/complete-onboarding"
        }
    }

    private func encode(_ dict: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: dict)
    }
}
