// LoginView.swift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false
    @State private var animateIn = false
    @State private var glowPulse = false

    enum Field { case email, password }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                backgroundLayer(geo: geo)

                loginCard
                    .frame(height: geo.size.height * 0.68)
                    .offset(y: animateIn ? 0 : geo.size.height * 0.7)
            }
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88).delay(0.05)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.3)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {

            // Fondo — PiumsBackground dark #121212
            Color.piumsBackground.ignoresSafeArea()

            // Glow naranja cálido detrás del ícono
            Circle()
                .fill(Color.piumsOrange.opacity(glowPulse ? 0.30 : 0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 55)
                .offset(y: geo.safeAreaInsets.top + 80)

            // Contenido superior centrado verticalmente en el área libre
            VStack(spacing: 0) {
                Spacer().frame(height: geo.safeAreaInsets.top + 20)

                // Logo wordmark naranja
                Image("PiumsLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.0), value: animateIn)

                Spacer().frame(height: 28)

                // Ícono — círculo marrón cálido exacto del artista
                ZStack {
                    // Halo suave detrás del círculo
                    Circle()
                        .fill(Color.piumsOrange.opacity(0.15))
                        .frame(width: 116, height: 116)
                        .blur(radius: 12)

                    // Círculo — PiumsBackgroundElevated con tinte naranja encima
                    Circle()
                        .fill(Color.piumsBackgroundElevated)
                        .frame(width: 92, height: 92)
                        .overlay(Circle().fill(Color.piumsOrange.opacity(0.22)))

                    Image(systemName: "ticket.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(Color.piumsOrange)
                }
                .scaleEffect(animateIn ? 1 : 0.6)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.08), value: animateIn)

                Spacer().frame(height: 20)

                // Título y subtítulo
                VStack(spacing: 6) {
                    Text("Panel de Clientes")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Reserva el mejor talento para tu evento")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.15), value: animateIn)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Card

    private var loginCard: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 28)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bienvenido de nuevo")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.piumsLabel)
                        Text("Accede a tu panel de control.")
                            .font(.subheadline)
                            .foregroundStyle(Color.piumsLabelSecondary)
                    }

                    // Campos
                    VStack(spacing: 14) {
                        fieldEmail
                        fieldPassword
                    }

                    // Error
                    if let msg = viewModel.errorMessage {
                        ErrorBannerView(message: msg)
                    }

                    // Botón login
                    loginButton

                    // Divisor
                    divider

                    // Social
                    HStack(spacing: 12) {
                        GoogleSignInButton {
                            Task { await viewModel.loginWithGoogle() }
                        }
                        .disabled(viewModel.isLoading)

                        AppleSignInButton { /* próximamente */ }
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
                        .accessibilityIdentifier("login_register_link")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 50)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.piumsBackgroundSecondary)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Fields

    private var fieldEmail: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CORREO")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.2)

            TextField("nombre@ejemplo.com", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(fieldBackground(isFocused: focused == .email))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(
                            focused == .email ? Color.piumsOrange.opacity(0.7) : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: focused == .email)
                .accessibilityIdentifier("login_email")
        }
    }

    private var fieldPassword: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CONTRASEÑA")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.2)

            HStack(spacing: 0) {
                Group {
                    if showPassword {
                        TextField("••••••••", text: $viewModel.password)
                            .accessibilityIdentifier("login_password")
                    } else {
                        SecureField("••••••••", text: $viewModel.password)
                            .accessibilityIdentifier("login_password")
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
                        .font(.system(size: 15))
                        .foregroundStyle(focused == .password ? Color.piumsOrange.opacity(0.8) : .secondary)
                        .padding(.trailing, 2)
                }
                .accessibilityIdentifier("login_toggle_password")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(fieldBackground(isFocused: focused == .password))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        focused == .password ? Color.piumsOrange.opacity(0.7) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focused == .password)

            HStack {
                Spacer()
                Button("¿Olvidaste tu contraseña?") {
                    viewModel.clearMessages()
                    viewModel.activeScreen = .forgotPassword
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.piumsOrange)
                .accessibilityIdentifier("login_forgot_password")
            }
            .padding(.top, 2)
        }
    }

    private func fieldBackground(isFocused: Bool) -> some ShapeStyle {
        AnyShapeStyle(Color.piumsBackgroundElevated)
    }

    // MARK: - Login Button

    private var loginButton: some View {
        let empty = viewModel.email.isEmpty || viewModel.password.isEmpty
        return Button {
            Task { await viewModel.login() }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Iniciando sesión…").font(.body.bold())
                    }
                } else {
                    Text("Iniciar sesión").font(.body.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: empty
                        ? [Color.piumsOrange.opacity(0.4), Color.piumsOrange.opacity(0.4)]
                        : [Color(red: 0.85, green: 0.38, blue: 0.12), Color(red: 0.72, green: 0.28, blue: 0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isLoading || empty)
        .animation(.easeInOut(duration: 0.2), value: empty)
        .accessibilityIdentifier("login_button")
    }

    // MARK: - Divisor

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.piumsSeparator).frame(height: 1)
            Text("O CONTINUAR CON")
                .font(.caption.bold())
                .foregroundStyle(Color.piumsLabelSecondary)
                .tracking(0.8)
                .fixedSize()
            Rectangle().fill(Color.piumsSeparator).frame(height: 1)
        }
    }
}

// MARK: - GoogleSignInButton

private struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
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
            .background(Color.piumsBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
    }
}

// MARK: - AppleSignInButton

private struct AppleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(Color.piumsLabel)
            .frame(width: 52, height: 52)
            .background(Color.piumsBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
