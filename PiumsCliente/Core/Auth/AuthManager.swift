// AuthManager.swift
import Foundation
import UIKit
import GoogleSignIn
import FirebaseAuth

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

    /// Google Sign-In → Firebase credential → Firebase ID token → POST /api/auth/firebase → Piums JWT
    func loginWithGoogle() async throws {
        // Obtener el view controller de presentación más alto disponible
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let window = activeScene?.keyWindow
                        ?? activeScene?.windows.first(where: { $0.isKeyWindow })
                        ?? activeScene?.windows.first,
              let rootVC = window.rootViewController else {
            throw AppError.http(statusCode: 0, message: "No se pudo obtener la ventana de presentación")
        }
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController { presentingVC = presented }

        // 1. Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let googleIdToken = result.user.idToken?.tokenString else {
            throw AppError.http(statusCode: 401, message: "No se obtuvo el token de Google")
        }
        let accessToken = result.user.accessToken.tokenString

        // 2. Firebase credential → Firebase ID token
        let credential = GoogleAuthProvider.credential(withIDToken: googleIdToken, accessToken: accessToken)
        let firebaseResult = try await Auth.auth().signIn(with: credential)
        let firebaseIdToken = try await firebaseResult.user.getIDToken()

        // 3. Piums backend
        let response: AuthResponse = try await APIClient.request(.firebaseAuth(token: firebaseIdToken))
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

    /// Flujo genérico: abre el OAuth del backend en ASWebAuthenticationSession,
    /// captura el ?token=JWT del callback HTTPS y verifica la sesión.
    /// El JWT del OAuth social dura 7 días (sin refreshToken).
    private func loginWithBackendOAuth(path: String, provider: String) async throws {
        let apiBase = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "https://backend.piums.io"
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"

        // CSRF: nonce aleatorio enviado en ?state= y verificado en el callback.
        // Requiere que el backend (Passport.js) reenvíe el parámetro state al redirect.
        // Si el backend no lo reenvía, se loguea una advertencia pero el login prosigue
        // para no bloquear la producción. Actualizar el backend para que lo soporte.
        let stateNonce = Self.generateNonce()

        guard var components = URLComponents(string: "\(apiBase)\(cleanPath)") else {
            throw AppError.http(statusCode: 0, message: "URL de autenticación inválida")
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "state", value: stateNonce))
        components.queryItems = queryItems
        guard let url = components.url else {
            throw AppError.http(statusCode: 0, message: "URL de autenticación inválida")
        }

        let callbackURL = try await OAuthWebLogin.shared.start(url: url)
        let cbComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)

        // Verificar CSRF state si el backend lo devuelve
        if let returnedState = cbComponents?.queryItems?.first(where: { $0.name == "state" })?.value {
            guard returnedState == stateNonce else {
                throw AppError.http(statusCode: 401, message: "Error de seguridad OAuth (state inválido). Intenta de nuevo.")
            }
        } else {
            #if DEBUG
            print("⚠️ OAuth: backend no reenvía 'state' — CSRF protection no activa para \(provider). Actualizar el backend.")
            #endif
        }

        if let errorParam = cbComponents?.queryItems?.first(where: { $0.name == "error" })?.value {
            throw AppError.http(statusCode: 401, message: errorDescriptionFor(errorParam, provider: provider))
        }

        guard let token = cbComponents?.queryItems?.first(where: { $0.name == "token" })?.value else {
            throw AppError.http(statusCode: 401, message: "No se recibió token de \(provider)")
        }

        // Validar que el token tiene estructura JWT antes de guardarlo en Keychain
        guard TokenStorage.looksLikeJWT(token) else {
            throw AppError.http(statusCode: 401, message: "Token de \(provider) con formato inválido")
        }

        TokenStorage.shared.accessToken = token
        await verify()
        guard currentUser != nil else {
            TokenStorage.shared.clearAll()
            throw AppError.http(statusCode: 401, message: "No se pudo verificar la sesión de \(provider)")
        }
    }

    // MARK: - Helpers

    private static func generateNonce(length: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
        // Tiempo mínimo de respuesta para dificultar enumeración de emails por timing.
        // Tanto "email existe" como "email no existe" tardan al menos 600ms.
        let start = ContinuousClock.now
        var caughtError: Error?
        do {
            let _: EmptyResponse = try await APIClient.request(.forgotPassword(email: email))
        } catch {
            caughtError = error
        }
        let elapsed = ContinuousClock.now - start
        let minDelay = Duration.milliseconds(600)
        if elapsed < minDelay {
            try? await Task.sleep(for: minDelay - elapsed)
        }
        if let caughtError { throw caughtError }
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
