// ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirm = false

    var body: some View {
        List {
            // Avatar + nombre
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.piumsOrange.opacity(0.15))
                            .frame(width: 68, height: 68)
                        Text(initials)
                            .font(.title2.bold())
                            .foregroundStyle(Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.user?.nombre ?? "Usuario")
                            .font(.headline)
                        Text(viewModel.user?.email ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Cliente")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.piumsOrange.opacity(0.12))
                            .foregroundStyle(Color.piumsOrange)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 8)
            }

            // Mensajes
            if let msg = viewModel.successMessage {
                Section { SuccessBannerView(message: msg) }
                    .listRowSeparator(.hidden)
            }
            if let msg = viewModel.errorMessage {
                Section { ErrorBannerView(message: msg) }
                    .listRowSeparator(.hidden)
            }

            // Cuenta
            Section("Cuenta") {
                Button {
                    viewModel.prepareEdit()
                    viewModel.showEditSheet = true
                } label: {
                    Label("Editar perfil", systemImage: "person.circle")
                }
                Button {
                    viewModel.showPasswordSheet = true
                    viewModel.clearMessages()
                } label: {
                    Label("Cambiar contraseña", systemImage: "lock.rotation")
                }
            }

            // Ayuda
            Section("Ayuda y soporte") {
                Label("Términos y condiciones", systemImage: "doc.text")
                Label("Política de privacidad", systemImage: "hand.raised")
                Label("Contactar soporte", systemImage: "message")
            }
            .foregroundStyle(.primary)

            // Cerrar sesión
            Section {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Mi Perfil")
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { Task { await viewModel.logout() } }
            Button("Cancelar", role: .cancel) {}
        }
        // Sheet — Editar perfil
        .sheet(isPresented: $viewModel.showEditSheet) {
            EditProfileSheet(viewModel: viewModel)
        }
        // Sheet — Cambiar contraseña
        .sheet(isPresented: $viewModel.showPasswordSheet) {
            ChangePasswordSheet(viewModel: viewModel)
        }
    }

    private var initials: String {
        let name = viewModel.user?.nombre ?? viewModel.user?.email ?? "U"
        return name.components(separatedBy: " ")
            .compactMap { $0.first.map(String.init) }
            .prefix(2)
            .joined()
            .uppercased()
    }
}

// MARK: - EditProfileSheet

private struct EditProfileSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre completo", text: $viewModel.editName)
                }
                if let msg = viewModel.errorMessage {
                    Section { ErrorBannerView(message: msg) }.listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await viewModel.saveProfile() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.piumsOrange)
                        .disabled(viewModel.isLoadingProfile)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { viewModel.showEditSheet = false }
                }
            }
            .overlay(alignment: .center) {
                if viewModel.isLoadingProfile { ProgressView() }
            }
        }
    }
}

// MARK: - ChangePasswordSheet

private struct ChangePasswordSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Contraseña actual") {
                    SecureField("Contraseña actual", text: $viewModel.currentPassword)
                }
                Section("Nueva contraseña") {
                    SecureField("Nueva contraseña", text: $viewModel.newPassword)
                    SecureField("Confirmar nueva contraseña", text: $viewModel.confirmNewPass)
                }
                if let msg = viewModel.errorMessage {
                    Section { ErrorBannerView(message: msg) }.listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Cambiar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await viewModel.changePassword() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.piumsOrange)
                        .disabled(viewModel.isLoadingPassword)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { viewModel.showPasswordSheet = false }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
}
