// LoginView.swift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ── Fondo ──────────────────────────────────────────
                backgroundLayer(geo: geo)

                // ── Card inferior ──────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Espaciador para empujar el card hacia abajo
                        Spacer().frame(height: geo.size.height * 0.38)

                        // Card
                        VStack(spacing: 28) {
                            // Encabezado
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bienvenido de nuevo")
                                    .font(.system(size: 30, weight: .bold))
                                Text("Accede a tu panel de control creativo.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Campos
                            VStack(spacing: 16) {
                                // Email
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EMAIL")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .tracking(1)
                                    TextField("nombre@ejemplo.com", text: $viewModel.email)
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .focused($focused, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit { focused = .password }
                                        .padding(16)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }

                                // Contraseña + olvidé
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("CONTRASEÑA")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .tracking(1)
                                    SecureField("••••••••", text: $viewModel.password)
                                        .textContentType(.password)
                                        .focused($focused, equals: .password)
                                        .submitLabel(.done)
                                        .onSubmit { Task { await viewModel.login() } }
                                        .padding(16)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))

                                    HStack {
                                        Spacer()
                                        Button("¿Olvidaste tu contraseña?") {
                                            viewModel.clearMessages()
                                            viewModel.activeScreen = .forgotPassword
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(Color.piumsOrange)
                                    }
                                }
                            }

                            // Error
                            if let msg = viewModel.errorMessage {
                                ErrorBannerView(message: msg)
                            }

                            // Botón principal
                            Button {
                                Task { await viewModel.login() }
                            } label: {
                                ZStack {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Iniciar sesión")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.piumsOrange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.piumsOrange.opacity(0.4), radius: 8, y: 4)
                            }
                            .disabled(viewModel.isLoading)

                            // Divisor social
                            HStack(spacing: 12) {
                                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                                Text("O CONTINUAR CON")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .tracking(0.8)
                                    .fixedSize()
                                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                            }

                            // Botones sociales
                            HStack(spacing: 20) {
                                SocialButton(systemImage: nil, label: "G") { /* Google Sign-In */ }
                                SocialButton(systemImage: "applelogo", label: nil) { /* Apple */ }
                                SocialButton(systemImage: nil, label: "♪") { /* TikTok */ }
                            }

                            // Registro
                            HStack(spacing: 4) {
                                Text("¿Aún no tienes cuenta?")
                                    .foregroundStyle(.secondary)
                                Button("Regístrate gratis") {
                                    viewModel.clearMessages()
                                    viewModel.activeScreen = .register
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.piumsOrange)
                            }
                            .font(.subheadline)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color(.systemBackground))
                                .ignoresSafeArea(edges: .bottom)
                        )
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(edges: .bottom)
            }
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(geo: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            // Imagen de fondo (desk photo simulada con gradiente hasta tener assets)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: geo.size.height * 0.55)
                .frame(maxWidth: .infinity)

            // Overlay oscuro suave
            Color.black.opacity(0.35)
                .frame(height: geo.size.height * 0.55)
                .frame(maxWidth: .infinity)

            // Logo Piums
            HStack(spacing: 8) {
                Image(systemName: "music.note.house.fill")
                    .font(.title3)
                Text("Piums")
                    .font(.title3.bold())
            }
            .foregroundStyle(.white)
            .padding(.top, geo.safeAreaInsets.top + 16)
            .padding(.leading, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - SocialButton

private struct SocialButton: View {
    let systemImage: String?
    let label: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                if let sys = systemImage {
                    Image(systemName: sys)
                        .font(.title3)
                        .foregroundStyle(.primary)
                } else if let lbl = label {
                    Text(lbl)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
