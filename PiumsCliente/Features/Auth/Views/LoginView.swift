// LoginView.swift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false

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
                                    
                                    HStack {
                                        Group {
                                            if showPassword {
                                                TextField("••••••••", text: $viewModel.password)
                                            } else {
                                                SecureField("••••••••", text: $viewModel.password)
                                            }
                                        }
                                        .textContentType(.password)
                                        .focused($focused, equals: .password)
                                        .submitLabel(.done)
                                        .onSubmit { Task { await viewModel.login() } }
                                        
                                        Button {
                                            showPassword.toggle()
                                        } label: {
                                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.trailing, 4)
                                    }
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
                            HStack(spacing: 12) {
                                // Google
                                GoogleSignInButton {
                                    Task { await viewModel.loginWithGoogle() }
                                }
                                .disabled(viewModel.isLoading)

                                SocialButton(systemImage: "applelogo", label: nil) { /* Apple — próximamente */ }
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
            Image("PiumsLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 32)
                .padding(.top, geo.safeAreaInsets.top + 16)
                .padding(.leading, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - GoogleSignInButton

private struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Logo Google (colores oficiales con SF Symbols como fallback)
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                    Text("G")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#4285F4"), Color(hex: "#34A853"),
                                         Color(hex: "#FBBC05"), Color(hex: "#EA4335")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Text("Continuar con Google")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
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
