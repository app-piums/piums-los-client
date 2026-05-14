// AuthManager.swift
import Foundation
import UIKit
import GoogleSignIn
import FirebaseAuth
import AuthenticationServices
import CryptoKit

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

    /// Apple Sign In → Firebase credential → Firebase ID token → POST /api/auth/firebase → Piums JWT
    func loginWithApple() async throws {
        let nonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(nonce)

        let appleCredential = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            let handler = AppleSignInHandler(nonce: nonce, continuation: continuation)
            self.appleSignInHandler = handler

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = handler
            controller.presentationContextProvider = handler
            controller.performRequests()
        }
        self.appleSignInHandler = nil

        guard let appleIDTokenData = appleCredential.identityToken,
              let appleIDToken = String(data: appleIDTokenData, encoding: .utf8) else {
            throw AppError.http(statusCode: 401, message: "No se obtuvo el token de Apple")
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: appleIDToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        let firebaseResult = try await Auth.auth().signIn(with: credential)
        let firebaseIdToken = try await firebaseResult.user.getIDToken()

        let response: AuthResponse = try await APIClient.request(.firebaseAuth(token: firebaseIdToken))
        store(response)
    }

    private var appleSignInHandler: AppleSignInHandler?

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
        UserDefaults.standard.removeObject(forKey: Self.userCacheKey)
        currentUser = nil
    }

    func refreshIfNeeded() async throws {
        // Cooldown: si el último refresh fue rechazado por rate limit, no reintentar hasta que expire
        if let blocked = refreshBlockedUntil, blocked > Date() {
            throw AppError.http(statusCode: 429, message: "Demasiadas solicitudes. Intenta en unos segundos.")
        }

        // Deduplicar: si ya hay un refresh en curso, esperar su resultado
        if let existing = refreshTask {
            try await existing.value
            return
        }

        let task = Task { @MainActor [self] in
            guard let refresh = TokenStorage.shared.refreshToken else { throw AppError.unauthorized }
            let response: AuthResponse = try await APIClient.request(.refreshToken(token: refresh), retryOnUnauthorized: false)
            store(response)
        }
        refreshTask = task
        do {
            try await task.value
            refreshTask = nil
            refreshBlockedUntil = nil
        } catch {
            refreshTask = nil
            // Rate limit del backend → cooldown 30s para no seguir reintentando en cascada
            if case .http(429, _) = error as? AppError {
                refreshBlockedUntil = Date().addingTimeInterval(30)
            }
            throw error
        }
    }

    // MARK: - Private

    private static let userCacheKey = "piums.currentUser"
    private var refreshTask: Task<Void, Error>?
    private var refreshBlockedUntil: Date?

    private func loadFromStorage() async {
        // 1. Restaurar usuario desde caché local — sin red, instantáneo
        if let data = UserDefaults.standard.data(forKey: Self.userCacheKey),
           let cached = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = cached
        }

        guard TokenStorage.shared.refreshToken != nil else {
            if currentUser != nil { currentUser = nil }
            return
        }

        // 2. Si el access token expiró, intentar refresh antes de verificar
        if TokenStorage.shared.isAccessTokenExpired {
            do { try await refreshIfNeeded() }
            catch {
                // Solo cerrar sesión si el refresh devuelve 401 (token revocado)
                if case .unauthorized = AppError(from: error) { await logout() }
                return
            }
        }

        // 3. Verificar en background — errores de red NO cierran sesión
        await verify()
    }

    private func verify() async {
        do {
            let wrapper: MeResponse = try await APIClient.request(.getMe)
            currentUser = wrapper.user
            saveUserLocally(wrapper.user)
        } catch let e as AppError where e == .unauthorized {
            await logout()
        } catch {
            // Errores de red, timeout, 5xx → mantener sesión activa
        }
    }

    private func store(_ response: AuthResponse) {
        TokenStorage.shared.accessToken  = response.token
        TokenStorage.shared.refreshToken = response.refreshToken
        currentUser = response.user
        saveUserLocally(response.user)
    }

    private func saveUserLocally(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.userCacheKey)
        }
    }
}

// MARK: - Apple Sign In nonce helpers (extensión privada)

extension AuthManager {
    static func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - AppleSignInHandler

@MainActor
private final class AppleSignInHandler: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private let nonce: String
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(nonce: String, continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.nonce = nonce
        self.continuation = continuation
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.keyWindow ?? UIWindow()
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: AppError.http(statusCode: 401, message: "Credencial Apple inválida"))
            return
        }
        continuation.resume(returning: credential)
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            continuation.resume(throwing: ASAuthorizationError(.canceled))
        } else {
            continuation.resume(throwing: AppError.http(statusCode: 401,
                message: "Error al autenticar con Apple: \(error.localizedDescription)"))
        }
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
