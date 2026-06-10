// LoginView.swift
import SwiftUI
import UIKit

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false
    @State private var animateIn = false
    @State private var glowPulse = false
    @State private var loginStep: LoginStep = .email
    @State private var keyboardHeight: CGFloat = 0

    enum Field { case email, password }
    enum LoginStep { case email, password, social }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                backgroundLayer(geo: geo)

                loginCard
                    .frame(height: geo.size.height * 0.60)
                    .offset(y: animateIn ? -keyboardHeight : geo.size.height * 0.7)
            }
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88).delay(0.05)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.3)) {
                glowPulse = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            guard let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = frame.height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // Smokey animated blobs — high-opacity, large displacement to match web SmokeyBackground
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince1970
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.28, blue: 0.04))
                        .frame(width: 300)
                        .blur(radius: 52)
                        .opacity(0.38)
                        .offset(x: CGFloat(sin(t * 0.5)) * 70,
                                y: CGFloat(cos(t * 0.4)) * 60 - 60)
                    Circle()
                        .fill(Color(red: 1.0, green: 0.22, blue: 0.02))
                        .frame(width: 260)
                        .blur(radius: 46)
                        .opacity(0.32)
                        .offset(x: CGFloat(cos(t * 0.6 + 1.0)) * 65,
                                y: CGFloat(sin(t * 0.5 + 0.5)) * 70 + 130)
                    Circle()
                        .fill(Color(red: 0.95, green: 0.25, blue: 0.0))
                        .frame(width: 280)
                        .blur(radius: 44)
                        .opacity(0.30)
                        .offset(x: CGFloat(sin(t * 0.7 + 2.0)) * 60,
                                y: CGFloat(cos(t * 0.45 + 1.0)) * 65 + 280)
                    Circle()
                        .fill(Color(red: 1.0, green: 0.35, blue: 0.05))
                        .frame(width: 220)
                        .blur(radius: 38)
                        .opacity(0.26)
                        .offset(x: CGFloat(cos(t * 0.4 + 0.7)) * 72,
                                y: CGFloat(sin(t * 0.65 + 1.5)) * 75 + 420)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: geo.safeAreaInsets.top + 20)

                Image("PiumsLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 180)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.0), value: animateIn)

                Spacer().frame(height: 20)

                VStack(spacing: 6) {
                    Text("¡Bienvenido a Piums!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text("El artista perfecto para tu próximo evento")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
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
                .fill(Color.piumsSeparator)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 24)

            ScrollViewReader { scrollProxy in
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
                .onChange(of: focused) { _, newFocus in
                    guard let f = newFocus else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy.scrollTo(f, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Paso 1: Email

    private var emailPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Ingresar o crear cuenta")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)

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
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.piumsBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.piumsSeparator, lineWidth: 1)
                    )
            }

            registerLink
        }
    }

    // MARK: - Paso 3: Redes sociales

    private var socialPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                Text("Ingresar o crear cuenta con:")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primary)
            }

            VStack(spacing: 12) {
                AppleSignInButton {
                    Task { await viewModel.loginWithApple() }
                }
                .disabled(viewModel.isLoading)
                GoogleSignInButton {
                    Task { await viewModel.loginWithGoogle() }
                }
                .disabled(viewModel.isLoading)
            }

            if let msg = viewModel.errorMessage {
                ErrorBannerView(message: msg)
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
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bienvenido")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Text(viewModel.email)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
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
                            focused == .email ? Color.piumsOrange.opacity(0.7) : Color.piumsSeparator,
                            lineWidth: focused == .email ? 1.5 : 1
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: focused == .email)
                .accessibilityIdentifier("login_email")
        }
        .id(Field.email)
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
                        focused == .password ? Color.piumsOrange.opacity(0.7) : Color.piumsSeparator,
                        lineWidth: focused == .password ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focused == .password)
        }
        .id(Field.password)
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
                        : [Color(.systemFill), Color(.systemFill)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(enabled ? .white : Color.secondary)
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
                        ? [Color(.systemFill), Color(.systemFill)]
                        : [Color(red: 0.85, green: 0.38, blue: 0.12), Color(red: 0.72, green: 0.28, blue: 0.07)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(empty ? Color.secondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isLoading || empty)
        .animation(.easeInOut(duration: 0.2), value: empty)
        .accessibilityIdentifier("login_button")
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("¿No tienes cuenta?")
                .foregroundStyle(.secondary)
            Button("Regístrate") {
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
            Rectangle().fill(Color.piumsSeparator).frame(height: 1)
            Circle().fill(Color.piumsSeparator).frame(width: 5, height: 5)
            Rectangle().fill(Color.piumsSeparator).frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Social Buttons (mismo estilo que app artista)

private struct AppleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.piumsLabel)
                    .frame(width: 26, height: 26)

                Text("Continuar con Apple")
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
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
        }
    }
}

private struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 26, height: 26)
                    Text("G")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                }
                .frame(width: 26, height: 26)

                Text("Continuar con Google")
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
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
