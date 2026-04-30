// AuthViewModel.swift
import Foundation
import UIKit

enum AuthScreen {
    case login, register, forgotPassword
}

@Observable
@MainActor
final class AuthViewModel {
    // MARK: - Campos
    var email       = ""
    var password    = ""
    var name        = ""
    var confirmPass = ""

    // MARK: - Estado
    var isLoading   = false
    var errorMessage: String?
    var successMessage: String?
    var activeScreen: AuthScreen = .login

    // MARK: - Acciones

    func login() async {
        guard validate(for: .login) else { return }
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        if let blocked = LoginRateLimiter.shared.shouldBlock(email: normalizedEmail) {
            errorMessage = blocked; return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.login(email: normalizedEmail, password: password)
            LoginRateLimiter.shared.reset(email: normalizedEmail)
        } catch let e as AppError {
            LoginRateLimiter.shared.recordFailure(email: normalizedEmail)
            errorMessage = e.errorDescription
        } catch {
            LoginRateLimiter.shared.recordFailure(email: normalizedEmail)
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func register() async {
        guard validate(for: .register) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.register(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func loginWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.loginWithGoogle()
        } catch let e as NSError where e.domain == "com.google.GIDSignIn" && e.code == -5 {
            // usuario canceló — sin mensaje de error
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginWithFacebook() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.loginWithFacebook()
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginWithTikTok() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.loginWithTikTok()
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forgotPassword() async {
        guard !email.isEmpty else { errorMessage = "Ingresa tu correo electrónico"; return }
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        if let blocked = LoginRateLimiter.shared.shouldBlock(email: "forgot:\(normalizedEmail)") {
            errorMessage = blocked; return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.forgotPassword(email: normalizedEmail)
            LoginRateLimiter.shared.reset(email: "forgot:\(normalizedEmail)")
            successMessage = "Revisa tu correo para restablecer tu contraseña"
        } catch let e as AppError {
            LoginRateLimiter.shared.recordFailure(email: "forgot:\(normalizedEmail)")
            errorMessage = e.errorDescription
        } catch {
            LoginRateLimiter.shared.recordFailure(email: "forgot:\(normalizedEmail)")
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Validaciones

    private func validate(for screen: AuthScreen) -> Bool {
        switch screen {
        case .login:
            if email.isEmpty || password.isEmpty {
                errorMessage = "Por favor completa todos los campos"
                return false
            }
        case .register:
            if name.isEmpty || email.isEmpty || password.isEmpty || confirmPass.isEmpty {
                errorMessage = "Por favor completa todos los campos"
                return false
            }
            if password != confirmPass {
                errorMessage = "Las contraseñas no coinciden"
                return false
            }
            if password.count < 8 {
                errorMessage = "La contraseña debe tener al menos 8 caracteres"
                return false
            }
        case .forgotPassword:
            break
        }
        return true
    }
}
