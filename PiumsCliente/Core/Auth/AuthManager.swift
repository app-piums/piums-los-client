// AuthManager.swift
import Foundation

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

    func forgotPassword(email: String) async throws {
        let _: EmptyResponse = try await APIClient.request(.forgotPassword(email: email))
    }

    func logout() async {
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

    // MARK: - Private helpers

    private func loadFromStorage() async {
        guard TokenStorage.shared.accessToken != nil else { return }
        await verify()
    }

    private func verify() async {
        do {
            let user: AuthUser = try await APIClient.request(.verifyToken)
            currentUser = user
        } catch {
            TokenStorage.shared.clearAll()
        }
    }

    private func store(_ response: AuthResponse) {
        TokenStorage.shared.accessToken  = response.accessToken
        TokenStorage.shared.refreshToken = response.refreshToken
        currentUser = response.user
    }
}

// MARK: - Response types

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct EmptyResponse: Decodable {}
