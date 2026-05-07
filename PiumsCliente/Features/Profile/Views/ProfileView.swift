// ProfileView.swift
import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirm = false
    @State private var showHowItWorks = false
    @State private var showVerifyIdentity = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @AppStorage("identityVerificationSubmitted") private var identitySubmitted = false
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

            // Verificación de identidad
            Section("Verificación") {
                if identitySubmitted {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Documentos enviados").font(.subheadline)
                            Text("En revisión por nuestro equipo").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.piumsOrange)
                    }
                    .listRowBackground(Color(.tertiarySystemGroupedBackground))
                } else {
                    Button { showVerifyIdentity = true } label: {
                        HStack {
                            Label("Verificar identidad", systemImage: "person.badge.shield.checkmark")
                            Spacer()
                            Text("Requerida")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color(.tertiarySystemGroupedBackground))
                }
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
        .sheet(isPresented: $showVerifyIdentity) {
            VerifyIdentitySheet {
                identitySubmitted = true
                showVerifyIdentity = false
            }
        }
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


// MARK: - VerifyIdentitySheet

private struct VerifyIdentitySheet: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var documentType: DocumentType = .dpi
    @State private var documentNumber = ""
    @State private var ciudad = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var docFrontUrl: String?
    @State private var docBackUrl: String?
    @State private var docSelfieUrl: String?
    @State private var docFrontImage: UIImage?
    @State private var docBackImage: UIImage?
    @State private var docSelfieImage: UIImage?
    @State private var isUploadingFront  = false
    @State private var isUploadingBack   = false
    @State private var isUploadingSelfie = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !documentNumber.trimmingCharacters(in: .whitespaces).isEmpty
            && docFrontUrl != nil
            && docSelfieUrl != nil
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de documento") {
                    Picker("Tipo", selection: $documentType) {
                        ForEach(DocumentType.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color(.tertiarySystemGroupedBackground))
                }

                Section("Datos personales") {
                    TextField("Número de documento", text: $documentNumber)
                        .keyboardType(.numbersAndPunctuation)
                        .listRowBackground(Color(.tertiarySystemGroupedBackground))
                    TextField("Ciudad de residencia", text: $ciudad)
                        .listRowBackground(Color(.tertiarySystemGroupedBackground))
                    DatePicker(
                        "Fecha de nacimiento",
                        selection: $birthDate,
                        in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                        displayedComponents: .date
                    )
                    .tint(Color.piumsOrange)
                    .listRowBackground(Color(.tertiarySystemGroupedBackground))
                }

                Section("Fotografías") {
                    HStack(spacing: 12) {
                        IdentityPhotoButton(
                            label: "Frente",
                            icon: "doc.text.fill",
                            image: docFrontImage,
                            url: docFrontUrl,
                            isLoading: isUploadingFront,
                            isRequired: true
                        ) { data in
                            docFrontImage = UIImage(data: data)
                            await upload(data, folder: "front") { docFrontUrl = $0 }
                        }

                        if documentType == .dpi {
                            IdentityPhotoButton(
                                label: "Dorso",
                                icon: "doc.fill",
                                image: docBackImage,
                                url: docBackUrl,
                                isLoading: isUploadingBack,
                                isRequired: false
                            ) { data in
                                docBackImage = UIImage(data: data)
                                await upload(data, folder: "back") { docBackUrl = $0 }
                            }
                        }

                        IdentityPhotoButton(
                            label: "Selfie",
                            icon: "person.fill.viewfinder",
                            image: docSelfieImage,
                            url: docSelfieUrl,
                            isLoading: isUploadingSelfie,
                            isRequired: true
                        ) { data in
                            docSelfieImage = UIImage(data: data)
                            await upload(data, folder: "selfie") { docSelfieUrl = $0 }
                        }
                    }
                    .listRowBackground(Color(.tertiarySystemGroupedBackground))

                    Text("Foto clara del documento. La selfie debe mostrar tu rostro junto al documento.")
                        .font(.caption).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if let err = errorMessage {
                    Section {
                        ErrorBannerView(message: err)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Verificar identidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color.piumsOrange : Color.secondary)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func upload(_ data: Data, folder: String, assign: @escaping (String) -> Void) async {
        switch folder {
        case "front":   isUploadingFront = true
        case "back":    isUploadingBack = true
        default:        isUploadingSelfie = true
        }
        defer {
            isUploadingFront = false
            isUploadingBack = false
            isUploadingSelfie = false
        }
        do {
            let resp: AvatarUploadResponseDTO = try await APIClient.uploadMultipart(
                .uploadDocument(folder: folder), imageData: data
            )
            if let url = resp.resolvedURL { assign(url) }
        } catch {}
    }

    private func save() async {
        guard let frontUrl = docFrontUrl, let selfieUrl = docSelfieUrl else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        var payload: [String: Any] = [
            "documentType": documentType.rawValue,
            "documentNumber": documentNumber.trimmingCharacters(in: .whitespaces),
            "documentFrontUrl": frontUrl,
            "documentSelfieUrl": selfieUrl,
            "birthDate": formatter.string(from: birthDate),
        ]
        if let backUrl = docBackUrl { payload["documentBackUrl"] = backUrl }
        let c = ciudad.trimmingCharacters(in: .whitespaces)
        if !c.isEmpty { payload["ciudad"] = c }
        do {
            let _: AuthUser = try await APIClient.request(.updateMyProfile(payload: payload))
            onDone()
        } catch {
            errorMessage = AppError(from: error).errorDescription ?? "Error al guardar"
        }
    }
}

// MARK: - IdentityPhotoButton

private struct IdentityPhotoButton: View {
    let label: String
    let icon: String
    let image: UIImage?
    let url: String?
    let isLoading: Bool
    let isRequired: Bool
    let onSelect: (Data) async -> Void

    @State private var pickerItem: PhotosPickerItem?

    var isUploaded: Bool { url != nil }

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 90)
                    .overlay {
                        if let img = image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 5) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text(label)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                if isRequired {
                                    Image(systemName: "asterisk")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isUploaded ? Color.piumsOrange.opacity(0.6) :
                                (isRequired ? Color.piumsOrange.opacity(0.3) : Color(.systemGray5)),
                                lineWidth: 1.5
                            )
                    )

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                        .padding(5)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(6)
                } else if isUploaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                        .background(Circle().fill(Color(.systemBackground)).padding(2))
                        .padding(6)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await onSelect(data)
                }
                pickerItem = nil
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(ThemeManager.shared)
}
