// RegisterView.swift
import SwiftUI

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focused: Field?

    enum Field { case name, email, password, confirmPass }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Fondo
                backgroundLayer(geo: geo)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: geo.size.height * 0.22)

                        // Card
                        VStack(spacing: 24) {
                            // Header
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Crea tu cuenta")
                                    .font(.system(size: 28, weight: .bold))
                                Text("Únete y comienza a contratar artistas.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Campos
                            VStack(spacing: 14) {
                                FieldBlock(label: "NOMBRE COMPLETO") {
                                    TextField("Tu nombre", text: $viewModel.name)
                                        .textContentType(.name)
                                        .focused($focused, equals: .name)
                                        .submitLabel(.next)
                                        .onSubmit { focused = .email }
                                        .fieldStyle()
                                }
                                FieldBlock(label: "EMAIL") {
                                    TextField("nombre@ejemplo.com", text: $viewModel.email)
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .focused($focused, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit { focused = .password }
                                        .fieldStyle()
                                }
                                FieldBlock(label: "CONTRASEÑA") {
                                    SecureField("••••••••", text: $viewModel.password)
                                        .textContentType(.newPassword)
                                        .focused($focused, equals: .password)
                                        .submitLabel(.next)
                                        .onSubmit { focused = .confirmPass }
                                        .fieldStyle()
                                }
                                FieldBlock(label: "CONFIRMAR CONTRASEÑA") {
                                    SecureField("••••••••", text: $viewModel.confirmPass)
                                        .textContentType(.newPassword)
                                        .focused($focused, equals: .confirmPass)
                                        .submitLabel(.done)
                                        .onSubmit { Task { await viewModel.register() } }
                                        .fieldStyle()
                                }
                            }

                            if let msg = viewModel.errorMessage {
                                ErrorBannerView(message: msg)
                            }

                            // Botón
                            Button {
                                Task { await viewModel.register() }
                            } label: {
                                ZStack {
                                    if viewModel.isLoading { ProgressView().tint(.white) }
                                    else { Text("Crear cuenta").font(.headline) }
                                }
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Color.piumsOrange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.piumsOrange.opacity(0.4), radius: 8, y: 4)
                            }
                            .disabled(viewModel.isLoading)

                            // Ya tengo cuenta
                            HStack(spacing: 4) {
                                Text("¿Ya tienes cuenta?").foregroundStyle(.secondary)
                                Button("Inicia sesión") {
                                    viewModel.clearMessages()
                                    viewModel.activeScreen = .login
                                }
                                .fontWeight(.semibold).foregroundStyle(Color.piumsOrange)
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
    }

    @ViewBuilder
    private func backgroundLayer(geo: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: geo.size.height * 0.35)
                .frame(maxWidth: .infinity)
            Color.black.opacity(0.35)
                .frame(height: geo.size.height * 0.35)
                .frame(maxWidth: .infinity)
            Image("PiumsLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 56)
                .padding(.top, geo.safeAreaInsets.top + 16)
                .padding(.leading, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Helpers locales

private struct FieldBlock<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1)
            content()
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    RegisterView(viewModel: AuthViewModel())
}
