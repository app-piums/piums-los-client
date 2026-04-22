// LoginView.swift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false
    @State private var animateIn = false
    @State private var glowPulse = false
    @State private var loginStep: LoginStep = .email

    enum Field { case email, password }
    enum LoginStep { case email, password, social }

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
            Color.piumsBackground.ignoresSafeArea()

            Circle()
                .fill(Color.piumsOrange.opacity(glowPulse ? 0.30 : 0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 55)
                .offset(y: geo.safeAreaInsets.top + 80)

            VStack(spacing: 0) {
                Spacer().frame(height: geo.safeAreaInsets.top + 20)

                Image("PiumsLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.0), value: animateIn)

                Spacer().frame(height: 28)

                ZStack {
                    Circle()
                        .fill(Color.piumsOrange.opacity(0.15))
                        .frame(width: 116, height: 116)
                        .blur(radius: 12)
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
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    switch loginStep {
                    case .email:
                        emailPanel
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .password:
                        passwordPanel
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .trailing).combined(with: .opacity)
                            ))
                    case .social:
                        socialPanel
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: loginStep)
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

    // MARK: - Paso 1: Email

    private var emailPanel: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Bienvenido de nuevo")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.piumsLabel)

            fieldEmail

            if let msg = viewModel.errorMessage {
                ErrorBannerView(message: msg)
            }

            continueButton(
                title: "Continuar",
                icon: "arrow.right",
                enabled: isValidEmail(viewModel.email)
            ) {
                viewModel.clearMessages()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    loginStep = .password
                    focused = .password
                }
            }

            divider

            Button {
                viewModel.clearMessages()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    loginStep = .social
                }
            } label: {
                Text("Continúa con Google, Facebook o TikTok")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.piumsLabel.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.piumsBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }

            registerLink
        }
    }

    // MARK: - Paso 2: Contraseña

    private var passwordPanel: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 12) {
                Button {
                    viewModel.clearMessages()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        loginStep = .email
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.piumsOrange)
                        .frame(width: 36, height: 36)
                        .background(Color.piumsBackgroundElevated)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bienvenido")
                        .font(.caption)
                        .foregroundStyle(Color.piumsLabelSecondary)
                    Text(viewModel.email)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.piumsLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }

            fieldPassword

            if let msg = viewModel.errorMessage {
                ErrorBannerView(message: msg)
            }

            loginButton

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

            registerLink
        }
    }

    // MARK: - Paso 3: Social

    private var socialPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ingresar o crear cuenta con:")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.piumsLabel)

            VStack(spacing: 12) {
                SocialSignInButton(provider: .google) {
                    Task { await viewModel.loginWithGoogle() }
                }
                SocialSignInButton(provider: .facebook) {
                    Task { await viewModel.loginWithFacebook() }
                }
                SocialSignInButton(provider: .tiktok) {
                    Task { await viewModel.loginWithTikTok() }
                }
            }
            .disabled(viewModel.isLoading)

            divider

            Button {
                viewModel.clearMessages()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    loginStep = .email
                }
            } label: {
                Text("Continúa con correo y contraseña")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.piumsLabel.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.piumsBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }

            registerLink

            (Text("Al crear una cuenta en Piums, aceptas los ")
                .font(.caption)
                .foregroundStyle(Color.piumsLabelSecondary)
            + Text("Términos de Servicio")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.piumsOrange)
            + Text(" y ")
                .font(.caption)
                .foregroundStyle(Color.piumsLabelSecondary)
            + Text("Política de Privacidad.")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.piumsOrange))
        }
    }

    // MARK: - Fields

    private var fieldEmail: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CORREO ELECTRÓNICO")
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
                .onSubmit {
                    guard isValidEmail(viewModel.email) else { return }
                    viewModel.clearMessages()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        loginStep = .password
                        focused = .password
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.piumsBackgroundElevated)
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
            .background(Color.piumsBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        focused == .password ? Color.piumsOrange.opacity(0.7) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focused == .password)
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private func continueButton(title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.body.bold())
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: enabled
                        ? [Color(red: 0.85, green: 0.38, blue: 0.12), Color(red: 0.72, green: 0.28, blue: 0.07)]
                        : [Color.piumsOrange.opacity(0.4), Color.piumsOrange.opacity(0.4)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }

    private var loginButton: some View {
        let empty = viewModel.password.isEmpty
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
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isLoading || empty)
        .animation(.easeInOut(duration: 0.2), value: empty)
        .accessibilityIdentifier("login_button")
    }

    private var registerLink: some View {
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

    // MARK: - Divisor

    private var divider: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            Circle().fill(Color.white.opacity(0.2)).frame(width: 5, height: 5)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - SocialSignInButton

private enum SocialProvider {
    case google, facebook, tiktok
    var displayName: String {
        switch self {
        case .google:   return "Google"
        case .facebook: return "Facebook"
        case .tiktok:   return "TikTok"
        }
    }
}

private struct SocialSignInButton: View {
    let provider: SocialProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SocialProviderIcon(provider: provider)
                    .frame(width: 26, height: 26)

                Text("Continuar con \(provider.displayName)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.piumsLabel)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .padding(.horizontal, 16)
            .background(Color.piumsBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

private struct SocialProviderIcon: View {
    let provider: SocialProvider

    var body: some View {
        switch provider {
        case .google:
            ZStack {
                Circle().fill(Color.white).frame(width: 26, height: 26)
                Text("G")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
            }
        case .facebook:
            ZStack {
                Circle().fill(Color(red: 0.23, green: 0.35, blue: 0.60)).frame(width: 26, height: 26)
                Text("f")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .tiktok:
            ZStack {
                Circle().fill(Color.black).frame(width: 26, height: 26)
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
