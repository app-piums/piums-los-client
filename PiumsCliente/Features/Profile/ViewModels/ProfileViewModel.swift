// ProfileViewModel.swift
import Foundation

@Observable
@MainActor
final class ProfileViewModel {
    var user: AuthUser? { AuthManager.shared.currentUser }

    // Edición
    var editName     = ""
    var editEmail    = ""
    var currentPassword = ""
    var newPassword     = ""
    var confirmNewPass  = ""

    var isLoadingProfile   = false
    var isLoadingPassword  = false
    var errorMessage: String?
    var successMessage: String?
    var showEditSheet      = false
    var showPasswordSheet  = false

    func prepareEdit() {
        editName  = user?.nombre ?? ""
        editEmail = user?.email  ?? ""
        errorMessage = nil
        successMessage = nil
    }

    func saveProfile() async {
        guard !editName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "El nombre no puede estar vacío"
            return
        }
        isLoadingProfile = true
        errorMessage = nil
        defer { isLoadingProfile = false }
        do {
            let _: AuthUser = try await APIClient.request(
                .updateMyProfile(payload: ["nombre": editName.trimmingCharacters(in: .whitespaces)])
            )
            successMessage = "Perfil actualizado correctamente"
            showEditSheet = false
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func changePassword() async {
        guard newPassword == confirmNewPass else {
            errorMessage = "Las contraseñas nuevas no coinciden"
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "La nueva contraseña debe tener al menos 8 caracteres"
            return
        }
        isLoadingPassword = true
        errorMessage = nil
        defer { isLoadingPassword = false }
        do {
            let _: EmptyResponse = try await APIClient.request(
                .changePassword(current: currentPassword, new: newPassword)
            )
            successMessage = "Contraseña actualizada"
            showPasswordSheet = false
            currentPassword = ""; newPassword = ""; confirmNewPass = ""
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func logout() async {
        await AuthManager.shared.logout()
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
