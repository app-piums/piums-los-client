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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.login(email: email.lowercased().trimmingCharacters(in: .whitespaces),
                                               password: password)
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
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
        // Obtener el rootViewController para presentar el flujo de Google
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            errorMessage = "No se pudo iniciar sesión con Google"
            return
        }
        do {
            try await AuthManager.shared.loginWithGoogle(presenting: root)
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forgotPassword() async {
        guard !email.isEmpty else { errorMessage = "Ingresa tu correo electrónico"; return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            try await AuthManager.shared.forgotPassword(email: email.lowercased().trimmingCharacters(in: .whitespaces))
            successMessage = "Revisa tu correo para restablecer tu contraseña"
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
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
