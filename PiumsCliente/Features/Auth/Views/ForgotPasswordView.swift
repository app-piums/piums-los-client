// ForgotPasswordView.swift
import SwiftUI

struct ForgotPasswordView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var emailFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Fondo
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(height: geo.size.height * 0.32)
                        .frame(maxWidth: .infinity)
                    Color.black.opacity(0.35)
                        .frame(height: geo.size.height * 0.32)
                        .frame(maxWidth: .infinity)
                    Image("PiumsLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 56)
                        .padding(.top, geo.safeAreaInsets.top + 16)
                        .padding(.leading, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Card
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: geo.size.height * 0.22)

                        VStack(spacing: 24) {
                            // Header
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Recuperar contraseña")
                                    .font(.system(size: 26, weight: .bold))
                                Text("Te enviaremos un enlace para restablecerla.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Campo email
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
                                    .focused($emailFocused)
                                    .submitLabel(.send)
                                    .onSubmit { Task { await viewModel.forgotPassword() } }
                                    .padding(16)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            // Mensajes
                            if let msg = viewModel.errorMessage   { ErrorBannerView(message: msg) }
                            if let msg = viewModel.successMessage { SuccessBannerView(message: msg) }

                            // Botón enviar
                            Button {
                                Task { await viewModel.forgotPassword() }
                            } label: {
                                ZStack {
                                    if viewModel.isLoading { ProgressView().tint(.white) }
                                    else { Text("Enviar enlace").font(.headline) }
                                }
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Color.piumsOrange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.piumsOrange.opacity(0.4), radius: 8, y: 4)
                            }
                            .disabled(viewModel.isLoading)

                            // Volver
                            Button {
                                viewModel.clearMessages()
                                viewModel.activeScreen = .login
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Volver al inicio de sesión")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.piumsOrange)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 32)
                        .padding(.bottom, 48)
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
}

#Preview {
    ForgotPasswordView(viewModel: AuthViewModel())
}
