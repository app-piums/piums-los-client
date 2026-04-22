// AuthManager.swift
import Foundation
import GoogleSignIn

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()
    private init() { Task { await loadFromStorage() } }

    var currentUser: AuthUser?
    var isAuthenticated: Bool { currentUser != nil }

    // MARK: - Public API

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await APIClient.request(.login(email: email, password: password))
        store(response)
    }

    func register(name: String, email: String, password: String) async throws {
        let response: AuthResponse = try await APIClient.request(
            .registerClient(name: name, email: email, password: password)
        )
        store(response)
    }

    /// Google Sign-In → Firebase idToken → POST /api/auth/firebase → Piums JWT
    func loginWithGoogle(presenting viewController: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AppError.http(statusCode: 401, message: "No se obtuvo el token de Google")
        }
        let response: AuthResponse = try await APIClient.request(.firebaseAuth(token: idToken))
        store(response)
    }

    /// Facebook OAuth — backend maneja Passport.js y redirige a:
    ///   https://piums.com/auth/callback?token=JWT&provider=facebook
    func loginWithFacebook() async throws {
        try await loginWithBackendOAuth(path: "/api/auth/facebook", provider: "Facebook")
    }

    /// TikTok OAuth (PKCE server-side) — backend redirige a:
    ///   https://piums.com/auth/callback?token=JWT&provider=tiktok
    func loginWithTikTok() async throws {
        try await loginWithBackendOAuth(path: "/api/auth/tiktok", provider: "TikTok")
    }

    /// Flujo genérico: abre el OAuth del backend en SFAuthenticationSession,
    /// captura el ?token=JWT del callback HTTPS y verifica la sesión.
    /// El JWT del OAuth social dura 7 días (sin refreshToken).
    private func loginWithBackendOAuth(path: String, provider: String) async throws {
        let base = "https://\(OAuthWebLogin.callbackHost)"
        guard let url = URL(string: "\(base)/api/auth\(path.hasPrefix("/") ? path : "/\(path)")") else {
            throw AppError.http(statusCode: 0, message: "URL de autenticación inválida")
        }
        let callbackURL = try await OAuthWebLogin.shared.start(url: url)
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        if let errorParam = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            throw AppError.http(statusCode: 401, message: errorDescriptionFor(errorParam, provider: provider))
        }
        guard let token = components?.queryItems?.first(where: { $0.name == "token" })?.value else {
            throw AppError.http(statusCode: 401, message: "No se recibió token de \(provider)")
        }
        TokenStorage.shared.accessToken = token
        await verify()
        guard currentUser != nil else {
            TokenStorage.shared.clearAll()
            throw AppError.http(statusCode: 401, message: "No se pudo verificar la sesión de \(provider)")
        }
    }

    private func errorDescriptionFor(_ code: String, provider: String) -> String {
        switch code {
        case "google_auth_failed":    return "Error al autenticar con Google"
        case "facebook_auth_failed":  return "Error al autenticar con Facebook"
        case "tiktok_auth_failed":    return "Error al autenticar con TikTok"
        case "tiktok_not_configured": return "TikTok no está configurado en el servidor"
        case "tiktok_denied":         return "Acceso denegado por TikTok"
        default:                      return "Error al autenticar con \(provider)"
        }
    }

    func forgotPassword(email: String) async throws {
        let _: EmptyResponse = try await APIClient.request(.forgotPassword(email: email))
    }

    func logout() async {
        GIDSignIn.sharedInstance.signOut()
        try? await Task<Void, Error> {
            let _: EmptyResponse = try await APIClient.request(.logout)
        }.value
        TokenStorage.shared.clearAll()
        currentUser = nil
    }

    func refreshIfNeeded() async throws {
        guard let refresh = TokenStorage.shared.refreshToken else { throw AppError.unauthorized }
        let response: AuthResponse = try await APIClient.request(.refreshToken(token: refresh))
        store(response)
    }

    // MARK: - Private

    private func loadFromStorage() async {
        guard TokenStorage.shared.accessToken != nil else { return }
        await verify()
    }

    private func verify() async {
        do {
            let wrapper: MeResponse = try await APIClient.request(.getMe)
            currentUser = wrapper.user
        } catch {
            TokenStorage.shared.clearAll()
        }
    }

    private func store(_ response: AuthResponse) {
        TokenStorage.shared.accessToken  = response.token
        TokenStorage.shared.refreshToken = response.refreshToken
        currentUser = response.user
    }
}

// MARK: - Response types

struct AuthResponse: Decodable {
    let token: String
    let refreshToken: String?
    let redirectUrl: String?
    let user: AuthUser
    let isNewUser: Bool?
}

struct MeResponse: Decodable {
    let user: AuthUser
}

struct EmptyResponse: Decodable {}
