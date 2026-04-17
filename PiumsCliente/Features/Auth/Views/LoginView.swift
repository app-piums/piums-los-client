// LoginView.swift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false
    @State private var animateIn = false

    enum Field { case email, password }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                backgroundLayer(geo: geo)

                VStack(spacing: 0) {
                    Spacer()
                    loginSheet
                }
                .ignoresSafeArea(edges: .bottom)
                .offset(y: animateIn ? 0 : 420)
            }
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                animateIn = true
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(geo: GeometryProxy) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.09, green: 0.07, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Glow sutil naranja
            Circle()
                .fill(Color.piumsOrange.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 65)
                .offset(x: -70, y: -50)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 1.4).delay(0.2), value: animateIn)

            // Contenido superior centrado
            VStack(spacing: 22) {
                Spacer().frame(height: geo.safeAreaInsets.top + 12)

                // Logo
                Image("PiumsLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 44)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -16)
                    .animation(.easeOut(duration: 0.55).delay(0.05), value: animateIn)

                // Ícono circular
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(Color.piumsOrange.opacity(0.13))
                        .frame(width: 82, height: 82)
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.piumsOrange, Color(red: 1, green: 0.62, blue: 0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(animateIn ? 1 : 0.55)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: animateIn)

                // Título + subtítulo
                VStack(spacing: 6) {
                    Text("Panel de Clientes")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Reserva el mejor talento para tu evento")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.48))
                        .multilineTextAlignment(.center)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)
                .animation(.easeOut(duration: 0.55).delay(0.25), value: animateIn)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sheet

    private var loginSheet: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 26)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bienvenido de nuevo")
                            .font(.system(size: 28, weight: .bold))
                        Text("Accede a tu panel de control creativo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Campos
                    VStack(spacing: 16) {
                        fieldEmail
                        fieldPassword
                    }

                    // Error
                    if let msg = viewModel.errorMessage {
                        ErrorBannerView(message: msg)
                    }

                    // Botón principal
                    loginButton

                    // Divisor
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                        Text("O CONTINUAR CON")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                            .fixedSize()
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    }

                    // Social
                    HStack(spacing: 12) {
                        GoogleSignInButton {
                            Task { await viewModel.loginWithGoogle() }
                        }
                        .disabled(viewModel.isLoading)

                        AppleButton { /* Apple — próximamente */ }
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
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Field Email

    private var fieldEmail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CORREO")
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Field Password

    private var fieldPassword: some View {
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

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 4)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Spacer()
                Button("¿Olvidaste tu contraseña?") {
                    viewModel.clearMessages()
                    viewModel.activeScreen = .forgotPassword
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.piumsOrange)
            }
        }
    }

    // MARK: - Login Button

    private var loginButton: some View {
        let disabled = viewModel.email.isEmpty || viewModel.password.isEmpty
        return Button {
            Task { await viewModel.login() }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.9)
                        Text("Iniciando sesión...")
                            .font(.body.bold())
                    }
                } else {
                    Text("Iniciar sesión")
                        .font(.body.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(disabled ? Color.piumsOrange.opacity(0.5) : Color.piumsOrange)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isLoading || disabled)
        .animation(.easeInOut(duration: 0.2), value: disabled)
    }
}

// MARK: - GoogleSignInButton

private struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 30, height: 30)
                    Text("G")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.26, green: 0.52, blue: 0.96),
                                         Color(red: 0.20, green: 0.66, blue: 0.33)],
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
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - AppleButton

private struct AppleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "applelogo")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
