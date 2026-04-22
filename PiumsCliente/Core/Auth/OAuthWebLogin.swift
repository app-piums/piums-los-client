// OAuthWebLogin.swift
import AuthenticationServices
import UIKit

/// Envuelve ASWebAuthenticationSession para el flujo OAuth server-side del backend.
/// El backend maneja todo el OAuth (Passport.js) y redirige a:
///   https://piums.com/auth/callback?token=JWT&provider={google|facebook|tiktok}
/// iOS 17.4+ intercepta ese redirect HTTPS sin Universal Links ni registro de URL scheme.
final class OAuthWebLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthWebLogin()
    private override init() {}

    // Host y path del callback — debe coincidir con FRONTEND_URL del backend
    // Producción: client.piums.io  (FRONTEND_URL del auth-service)
    static let callbackHost = "client.piums.io"
    static let callbackPath = "/auth/callback"

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    // MARK: - Session

    private var activeSession: ASWebAuthenticationSession?

    @MainActor
    func start(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let callback = ASWebAuthenticationSession.Callback.https(
                host: Self.callbackHost,
                path: Self.callbackPath
            )
            let s = ASWebAuthenticationSession(url: url, callback: callback) { [weak self] callbackURL, error in
                self?.activeSession = nil
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: cancelled
                        ? AppError.http(statusCode: 0, message: "Inicio de sesión cancelado")
                        : AppError(from: error))
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AppError.http(statusCode: 401, message: "No se recibió respuesta del proveedor"))
                }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            activeSession = s
            s.start()
        }
    }
}
