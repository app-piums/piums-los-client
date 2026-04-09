// AuthFlowView.swift — contenedor de navegación para Auth
import SwiftUI

struct AuthFlowView: View {
    @State private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            switch viewModel.activeScreen {
            case .login:
                LoginView(viewModel: viewModel)
            case .register:
                RegisterView(viewModel: viewModel)
            case .forgotPassword:
                ForgotPasswordView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.activeScreen)
    }
}

#Preview {
    AuthFlowView()
}
