// APIEndpoint.swift
import Foundation

enum APIEndpoint {
    // ── Auth ──────────────────────────────────────────────
    case login(email: String, password: String)
    case registerClient(name: String, email: String, password: String)
    case firebaseAuth(token: String)
    case refreshToken(token: String)
    case logout
    case getMe                           // GET /api/auth/me  (requiere token)
    case forgotPassword(email: String)

    // ── Artists ───────────────────────────────────────────
    case getArtist(id: String)

    // ── Search (listado y búsqueda de artistas) ───────────
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
    case markNotificationRead(id: String)
    case registerPushToken(token: String, platform: String)

    // ── Disputes / Quejas ─────────────────────────────────
    case listMyDisputes(page: Int)
    case createDispute(payload: [String: Any])
    case getDispute(id: String)
    case addDisputeMessage(id: String, message: String)

    // ── Users ─────────────────────────────────────────────
    case getMyProfile
    case updateMyProfile(payload: [String: Any])
    case changePassword(current: String, new: String)
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
             .registerPushToken, .forgotPassword:
            return "POST"
        case .updateMyProfile:
            return "PATCH"
        case .cancelBooking:
            return "POST"           // POST /bookings/:id/cancel
        case .logout:
            return "POST"
        default:
            return "GET"
        }
    }

    var body: Data? {
        switch self {
        case .login(let e, let p):
            return try? JSONSerialization.data(withJSONObject: ["email": e, "password": p])
        case .registerClient(let n, let e, let p):
            return try? JSONSerialization.data(withJSONObject: ["nombre": n, "email": e, "password": p])
        case .firebaseAuth(let t):
            return try? JSONSerialization.data(withJSONObject: ["firebaseToken": t])
        case .refreshToken(let t):
            return try? JSONSerialization.data(withJSONObject: ["refreshToken": t])
        case .forgotPassword(let e):
            return try? JSONSerialization.data(withJSONObject: ["email": e])
        case .createBooking(let p), .createReview(let p), .createDispute(let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .addDisputeMessage(_, let msg):
            return try? JSONSerialization.data(withJSONObject: ["message": msg])
        case .updateMyProfile(let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .registerPushToken(let t, let pl):
            return try? JSONSerialization.data(withJSONObject: ["token": t, "platform": pl])
        case .changePassword(let cur, let new):
            return try? JSONSerialization.data(withJSONObject: ["currentPassword": cur, "newPassword": new])
        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .registerClient, .firebaseAuth, .forgotPassword,
             .searchArtists, .getArtist, .listReviews:
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

        // Search — listado y búsqueda unificados
        case .searchArtists(let q, let pg, let lm, let cat, let city):
            var p = "/api/search/artists?page=\(pg)&limit=\(lm)"
            if let q = q, !q.isEmpty {
                p += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
            }
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
        case .getAvailableSlots(let a, let d):
            return "/api/availability/time-slots?artistId=\(a)&date=\(d)"

        // Reviews
        case .listReviews(let a, let pg):      return "/api/reviews?artistId=\(a)&page=\(pg)&limit=10"
        case .createReview:                    return "/api/reviews"

        // Notifications
        case .listNotifications(let pg):       return "/api/notifications?page=\(pg)&limit=20"
        case .markNotificationRead(let id):    return "/api/notifications/\(id)/read"
        case .registerPushToken:               return "/api/notifications/push-token"

        // Disputes
        case .listMyDisputes(let pg):          return "/api/disputes/me?page=\(pg)&limit=20"
        case .createDispute:                   return "/api/disputes"
        case .getDispute(let id):              return "/api/disputes/\(id)"
        case .addDisputeMessage(let id, _):    return "/api/disputes/\(id)/messages"

        // Users
        case .getMyProfile:                    return "/api/users/me"
        case .updateMyProfile:                 return "/api/users/me"
        case .changePassword:                  return "/api/auth/change-password"
        }
    }
}
