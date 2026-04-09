// APIEndpoint.swift
import Foundation

enum APIEndpoint {
    // ── Auth ──────────────────────────────────────────────
    case login(email: String, password: String)
    case registerClient(name: String, email: String, password: String)
    case firebaseAuth(token: String)
    case refreshToken(token: String)
    case logout
    case verifyToken
    case forgotPassword(email: String)

    // ── Artists ───────────────────────────────────────────
    case listArtists(page: Int, limit: Int, category: String?, cityId: String?, q: String?)
    case getArtist(id: String)
    case searchArtists(q: String, page: Int)

    // ── Catalog ───────────────────────────────────────────
    case listServices(artistId: String)
    case getService(id: String)

    // ── Bookings ──────────────────────────────────────────
    case createBooking(payload: [String: Any])
    case listMyBookings(status: String?, page: Int)
    case getBooking(id: String)
    case cancelBooking(id: String)
    case checkAvailability(artistId: String, startTime: String, endTime: String)
    case getAvailableSlots(artistId: String, date: String)

    // ── Events ────────────────────────────────────────────
    case listEvents(page: Int)
    case createEvent(payload: [String: Any])
    case getEvent(id: String)
    case updateEvent(id: String, payload: [String: Any])
    case cancelEvent(id: String)

    // ── Reviews ───────────────────────────────────────────
    case listReviews(artistId: String, page: Int)
    case createReview(payload: [String: Any])

    // ── Notifications ─────────────────────────────────────
    case listNotifications(page: Int)
    case markNotificationRead(id: String)
    case registerPushToken(token: String, platform: String)

    // ── Users ─────────────────────────────────────────────
    case getMyProfile
    case updateMyProfile(payload: [String: Any])
    case changePassword(current: String, new: String)
}

extension APIEndpoint {
    private static var base: String {
        Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "https://piums.com"
    }

    var url: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "\(Self.base)/api\(path)")!
    }

    var method: String {
        switch self {
        case .login, .registerClient, .firebaseAuth,
             .createBooking, .createEvent, .createReview,
             .registerPushToken, .forgotPassword:
            return "POST"
        case .updateEvent, .updateMyProfile:
            return "PUT"
        case .cancelBooking, .cancelEvent:
            return "DELETE"
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
        case .createBooking(let p), .createEvent(let p), .createReview(let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .updateEvent(_, let p), .updateMyProfile(let p):
            return try? JSONSerialization.data(withJSONObject: p)
        case .registerPushToken(let t, let pl):
            return try? JSONSerialization.data(withJSONObject: ["token": t, "platform": pl])
        case .changePassword(let cur, let new):
            return try? JSONSerialization.data(withJSONObject: ["currentPassword": cur, "newPassword": new])
        default:
            return nil
        }
    }

    private var path: String {
        switch self {
        case .login:                           return "/auth/login"
        case .registerClient:                  return "/auth/register/client"
        case .firebaseAuth:                    return "/auth/firebase"
        case .refreshToken:                    return "/auth/refresh"
        case .logout:                          return "/auth/logout"
        case .verifyToken:                     return "/auth/verify"
        case .forgotPassword:                  return "/auth/forgot-password"

        case .listArtists(let pg, let lm, let cat, let city, let q):
            var p = "/artists?page=\(pg)&limit=\(lm)"
            if let cat  = cat  { p += "&category=\(cat)" }
            if let city = city { p += "&cityId=\(city)" }
            if let q    = q    { p += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)" }
            return p
        case .getArtist(let id):               return "/artists/\(id)"
        case .searchArtists(let q, let pg):    return "/search?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)&page=\(pg)"

        case .listServices(let artistId):      return "/catalog/services?artistId=\(artistId)"
        case .getService(let id):              return "/catalog/services/\(id)"

        case .createBooking:                   return "/bookings"
        case .listMyBookings(let s, let pg):
            var p = "/bookings?page=\(pg)&limit=20"
            if let s = s { p += "&status=\(s)" }
            return p
        case .getBooking(let id):              return "/bookings/\(id)"
        case .cancelBooking(let id):           return "/bookings/\(id)/cancel"
        case .checkAvailability(let a, let s, let e):
            return "/bookings/availability/check?artistId=\(a)&startTime=\(s)&endTime=\(e)"
        case .getAvailableSlots(let a, let d):
            return "/bookings/availability/slots?artistId=\(a)&startDate=\(d)&endDate=\(d)"

        case .listEvents(let pg):              return "/bookings/events?page=\(pg)&limit=20"
        case .createEvent:                     return "/bookings/events"
        case .getEvent(let id):                return "/bookings/events/\(id)"
        case .updateEvent(let id, _):          return "/bookings/events/\(id)"
        case .cancelEvent(let id):             return "/bookings/events/\(id)/cancel"

        case .listReviews(let a, let pg):      return "/reviews?artistId=\(a)&page=\(pg)"
        case .createReview:                    return "/reviews"

        case .listNotifications(let pg):       return "/notifications?page=\(pg)&limit=20"
        case .markNotificationRead(let id):    return "/notifications/\(id)/read"
        case .registerPushToken:               return "/notifications/push-token"

        case .getMyProfile:                    return "/users/me"
        case .updateMyProfile:                 return "/users/me"
        case .changePassword:                  return "/users/me/password"
        }
    }
}
