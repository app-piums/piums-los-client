// RegisterView.swift
import SwiftUI

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false
    @State private var showConfirm  = false
    @State private var animateIn    = false
    @State private var glowPulse    = false
    @State private var acceptTerms  = false

    enum Field { case name, email, password, confirmPass }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                backgroundLayer(geo: geo)

                registerCard
                    .frame(height: geo.size.height * 0.78)
                    .offset(y: animateIn ? 0 : geo.size.height * 0.8)
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
                .fill(Color.piumsOrange.opacity(glowPulse ? 0.28 : 0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(y: geo.safeAreaInsets.top + 60)

            VStack(spacing: 0) {
                Spacer().frame(height: geo.safeAreaInsets.top + 20)

                Image("PiumsLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: animateIn)

                Spacer().frame(height: 22)

                ZStack {
                    Circle()
                        .fill(Color.piumsOrange.opacity(0.13))
                        .frame(width: 100, height: 100)
                        .blur(radius: 10)

                    Circle()
                        .fill(Color.piumsBackgroundElevated)
                        .frame(width: 78, height: 78)
                        .overlay(Circle().fill(Color.piumsOrange.opacity(0.22)))

                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Color.piumsOrange)
                }
                .scaleEffect(animateIn ? 1 : 0.6)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.08), value: animateIn)

                Spacer().frame(height: 14)

                VStack(spacing: 5) {
                    Text("Únete a Piums")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Contrata el mejor talento para tu evento")
                        .font(.system(size: 13))
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

    private var registerCard: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    // Header
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Crea tu cuenta")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.piumsLabel)
                        Text("Rellena los datos para comenzar.")
                            .font(.subheadline)
                            .foregroundStyle(Color.piumsLabelSecondary)
                    }

                    // Campos
                    VStack(spacing: 14) {
                        fieldName
                        fieldEmail
                        fieldPassword
                        fieldConfirmPassword
                    }

                    // Validación de contraseña
                    if !viewModel.password.isEmpty {
                        PasswordStrengthBar(password: viewModel.password)
                    }

                    // Términos
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { acceptTerms.toggle() }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(acceptTerms ? Color.piumsOrange : Color.white.opacity(0.25), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                if acceptTerms {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.piumsOrange)
                                        .frame(width: 20, height: 20)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text("Acepto los **Términos y condiciones** y la **Política de privacidad** de Piums.")
                                .font(.footnote)
                                .foregroundStyle(Color.piumsLabelSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("register_terms")

                    // Error
                    if let msg = viewModel.errorMessage {
                        ErrorBannerView(message: msg)
                    }

                    // Botón registrar
                    Button {
                        guard acceptTerms else {
                            viewModel.errorMessage = "Debes aceptar los términos y condiciones"
                            return
                        }
                        Task { await viewModel.register() }
                    } label: {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Crear cuenta")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: canSubmit
                                    ? [Color(red: 0.85, green: 0.38, blue: 0.12), Color(red: 0.72, green: 0.28, blue: 0.07)]
                                    : [Color.piumsOrange.opacity(0.35), Color.piumsOrange.opacity(0.35)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: canSubmit ? Color.piumsOrange.opacity(0.38) : .clear, radius: 8, y: 4)
                    }
                    .disabled(viewModel.isLoading || !canSubmit)
                    .accessibilityIdentifier("register_submit")

                    // Ya tengo cuenta
                    HStack(spacing: 4) {
                        Text("¿Ya tienes cuenta?")
                            .foregroundStyle(.secondary)
                        Button("Inicia sesión") {
                            viewModel.clearMessages()
                            viewModel.activeScreen = .login
                        }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("register_login_link")
                        .foregroundStyle(Color.piumsOrange)
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

    private var canSubmit: Bool {
        !viewModel.name.isEmpty && !viewModel.email.isEmpty &&
        !viewModel.password.isEmpty && !viewModel.confirmPass.isEmpty && acceptTerms
    }

    // MARK: - Fields

    private var fieldName: some View {
        fieldBlock(label: "NOMBRE COMPLETO", isFocused: focused == .name) {
            TextField("Tu nombre completo", text: $viewModel.name)
                .textContentType(.name)
                .focused($focused, equals: .name)
                .submitLabel(.next)
                .onSubmit { focused = .email }
                .accessibilityIdentifier("register_name")
        }
    }

    private var fieldEmail: some View {
        fieldBlock(label: "CORREO ELECTRÓNICO", isFocused: focused == .email) {
            TextField("nombre@ejemplo.com", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .accessibilityIdentifier("register_email")
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
                            .accessibilityIdentifier("register_password")
                    } else {
                        SecureField("••••••••", text: $viewModel.password)
                            .accessibilityIdentifier("register_password")
                    }
                }
                .textContentType(.newPassword)
                .focused($focused, equals: .password)
                .submitLabel(.next)
                .onSubmit { focused = .confirmPass }

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(focused == .password ? Color.piumsOrange.opacity(0.8) : .secondary)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .background(Color.piumsBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(focused == .password ? Color.piumsOrange.opacity(0.7) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: focused == .password)
        }
    }

    private var fieldConfirmPassword: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CONFIRMAR CONTRASEÑA")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.2)

            HStack(spacing: 0) {
                Group {
                    if showConfirm {
                        TextField("••••••••", text: $viewModel.confirmPass)
                            .accessibilityIdentifier("register_confirm")
                    } else {
                        SecureField("••••••••", text: $viewModel.confirmPass)
                            .accessibilityIdentifier("register_confirm")
                    }
                }
                .textContentType(.newPassword)
                .focused($focused, equals: .confirmPass)
                .submitLabel(.done)
                .onSubmit {
                    guard acceptTerms else {
                        viewModel.errorMessage = "Debes aceptar los términos y condiciones"
                        return
                    }
                    Task { await viewModel.register() }
                }

                Button { showConfirm.toggle() } label: {
                    Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(focused == .confirmPass ? Color.piumsOrange.opacity(0.8) : .secondary)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .background(Color.piumsBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        focused == .confirmPass
                            ? (viewModel.confirmPass.isEmpty || viewModel.password == viewModel.confirmPass
                                ? Color.piumsOrange.opacity(0.7)
                                : Color.red.opacity(0.6))
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focused == .confirmPass)
        }
    }

    // Función helper para campos genéricos
    @ViewBuilder
    private func fieldBlock<F: View>(
        label: String,
        isFocused: Bool,
        @ViewBuilder content: () -> F
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.2)
            content()
                .padding(.horizontal, 16).padding(.vertical, 15)
                .background(Color.piumsBackgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(isFocused ? Color.piumsOrange.opacity(0.7) : Color.clear, lineWidth: 1.5)
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Password Strength

private struct PasswordStrengthBar: View {
    let password: String

    private var strength: Int {
        var s = 0
        if password.count >= 8 { s += 1 }
        if password.count >= 12 { s += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { s += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { s += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { s += 1 }
        return s
    }

    private var label: String {
        switch strength {
        case 0...1: return "Muy débil"
        case 2:     return "Débil"
        case 3:     return "Moderada"
        case 4:     return "Fuerte"
        default:    return "Muy fuerte"
        }
    }

    private var color: Color {
        switch strength {
        case 0...1: return .red
        case 2:     return .orange
        case 3:     return Color(hex: "#F59E0B")
        case 4:     return Color(hex: "#10B981")
        default:    return Color(hex: "#059669")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i < strength ? color : Color.white.opacity(0.12))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: strength)
                }
            }
            Text("Seguridad: \(label)")
                .font(.caption)
                .foregroundStyle(color)
                .animation(.easeInOut(duration: 0.2), value: label)
        }
    }
}

#Preview {
    RegisterView(viewModel: AuthViewModel())
}
