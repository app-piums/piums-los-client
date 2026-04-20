// RootView.swift — decide si mostrar onboarding, auth o la app principal
import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var deepLinkBookingId: String?
    @State private var isLoading = true

    private var isUITestingAuth: Bool { CommandLine.arguments.contains("UI_TESTING_AUTH") }
    private var isUITestingLoggedIn: Bool { CommandLine.arguments.contains("UI_TESTING_LOGGED_IN") }

    var body: some View {
        Group {
            if isUITestingAuth {
                AuthFlowView()
            } else if isUITestingLoggedIn {
                MainTabView(deepLinkBookingId: .constant(nil))
            } else if isLoading {
                // Splash screen con logo
                ZStack {
                    Color.piumsOrange.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image("PiumsLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 140)
                            .foregroundStyle(.white)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            } else if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation { hasSeenOnboarding = true }
                }
            } else if auth.isAuthenticated {
                MainTabView(deepLinkBookingId: $deepLinkBookingId)
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToBooking)) { notif in
            if let bookingId = notif.userInfo?["bookingId"] as? String {
                deepLinkBookingId = bookingId
            }
        }
        .task {
            // Simular tiempo de carga inicial
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 segundos
            withAnimation {
                isLoading = false
            }
        }
    }
}

#Preview {
    RootView()
}
