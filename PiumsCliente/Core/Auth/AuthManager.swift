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
    let refreshToken: String
    let redirectUrl: String?
    let user: AuthUser
}

struct MeResponse: Decodable {
    let user: AuthUser
}

struct EmptyResponse: Decodable {}
