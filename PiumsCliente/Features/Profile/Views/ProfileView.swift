// ProfileView.swift
import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirm = false
    @State private var showHowItWorks = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            // Avatar + nombre
            Section {
                HStack(spacing: 16) {
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarCircle
                            if isUploadingPhoto {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(width: 68, height: 68)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color.piumsOrange)
                                    .clipShape(Circle())
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isUploadingPhoto)
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        Task { await uploadPhoto(item) }
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
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
            }

            // Mensajes
            if let msg = viewModel.successMessage {
                Section { SuccessBannerView(message: msg).listRowBackground(Color.clear) }
                    .listRowSeparator(.hidden)
            }
            if let msg = viewModel.errorMessage {
                Section { ErrorBannerView(message: msg).listRowBackground(Color.clear) }
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
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
                Button {
                    viewModel.showPasswordSheet = true
                    viewModel.clearMessages()
                } label: {
                    Label("Cambiar contraseña", systemImage: "lock.rotation")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
                NavigationLink(destination: PaymentsView()) {
                    Label("Mis pagos", systemImage: "creditcard")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
            }

            // Apariencia
            Section("Apariencia") {
                Toggle(isOn: Binding(
                    get: { themeManager.storedScheme == "dark" },
                    set: { themeManager.storedScheme = $0 ? "dark" : "light" }
                )) {
                    Label("Modo oscuro", systemImage: "moon.fill")
                }
                .tint(Color.piumsOrange)
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
            }

            // Ayuda y soporte
            Section("Ayuda y soporte") {
                Button { showHowItWorks = true } label: {
                    Label("¿Cómo funciona Piums?", systemImage: "questionmark.circle")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
                NavigationLink(destination: QuejasView()) {
                    Label("Mis quejas", systemImage: "exclamationmark.bubble")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
                Button { openURL(URL(string: "https://piums.io/terminos")!) } label: {
                    Label("Términos y condiciones", systemImage: "doc.text")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
                Button { openURL(URL(string: "https://piums.io/privacidad")!) } label: {
                    Label("Política de privacidad", systemImage: "hand.raised")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
                Button { openURL(URL(string: "mailto:soporte@piums.io")!) } label: {
                    Label("Contactar soporte", systemImage: "message")
                }
                .listRowBackground(Color(.tertiarySystemGroupedBackground))
            }
            .foregroundStyle(.primary)

            // Cerrar sesión
            Section {
                Button(role: .destructive) { showLogoutConfirm = true } label: {
                    HStack {
                        Spacer()
                        Text("Cerrar Sesión")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color(.tertiarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mi Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(themeManager.colorScheme)
        .sheet(isPresented: $viewModel.showEditSheet) {
            EditProfileSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPasswordSheet) {
            ChangePasswordSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showHowItWorks) { HowItWorksView() }
        .alert("¿Cerrar sesión?", isPresented: $showLogoutConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Cerrar sesión", role: .destructive) {
                Task { await viewModel.logout() }
            }
        } message: {
            Text("Se cerrará tu sesión actual y tendrás que iniciar sesión de nuevo.")
        }
    }

    @ViewBuilder
    private var avatarCircle: some View {
        if let url = viewModel.user?.avatar, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(Circle())
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(Color.piumsOrange.opacity(0.15))
                .frame(width: 68, height: 68)
            Text(initials)
                .font(.title2.bold())
                .foregroundStyle(Color.piumsOrange)
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

    // MARK: - Avatar upload

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = resizedJPEG(from: image, maxDimension: 800, quality: 0.7) else {
            photoItem = nil; return
        }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false; photoItem = nil }

        var request = URLRequest(url: APIEndpoint.uploadAvatar.url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        if let token = TokenStorage.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = "piumsboundary\(Int(Date().timeIntervalSince1970))"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let crlf = "\r\n"
        var body = Data()
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                let msg = (try? JSONDecoder().decode([String: String].self, from: responseData))?["message"]
                       ?? (try? JSONDecoder().decode([String: String].self, from: responseData))?["error"]
                       ?? String(data: responseData, encoding: .utf8)?.prefix(200).description
                       ?? "Error \(http.statusCode)"
                viewModel.errorMessage = msg
                return
            }
            if let newURL = extractAvatarURL(from: responseData) {
                URLCache.shared.removeAllCachedResponses()
                AuthManager.shared.currentUser = AuthManager.shared.currentUser.map {
                    AuthUser(id: $0.id, email: $0.email, nombre: $0.nombre,
                             role: $0.role, avatar: newURL,
                             emailVerified: $0.emailVerified, status: $0.status)
                }
                viewModel.successMessage = "Foto actualizada"
            }
        } catch {
            viewModel.errorMessage = "Error al subir la foto: \(error.localizedDescription)"
        }
    }

    private func resizedJPEG(from image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }

    private func extractAvatarURL(from data: Data) -> String? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let resp = try? decoder.decode(AvatarUploadResponseDTO.self, from: data),
           let url = resp.resolvedURL { return url }
        if let resp = try? decoder.decode(AvatarUploadUserWrapperDTO.self, from: data),
           let url = resp.resolvedURL { return url }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json.values.compactMap { $0 as? String }
                .first { $0.hasPrefix("http") && (
                    $0.contains("avatar") || $0.contains("image") ||
                    $0.contains("upload") || $0.contains("cdn")
                )}
        }
        return nil
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
        .environmentObject(ThemeManager.shared)
}
