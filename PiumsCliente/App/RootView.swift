// RootView.swift — decide si mostrar onboarding, auth o la app principal
import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var deepLinkBookingId: String?
    @State private var showSplash = true

    private var isUITestingAuth: Bool { CommandLine.arguments.contains("UI_TESTING_AUTH") }
    private var isUITestingLoggedIn: Bool { CommandLine.arguments.contains("UI_TESTING_LOGGED_IN") }

    var body: some View {
        ZStack {
            // Capa base negra siempre visible (igual que app de artista)
            Color.black.ignoresSafeArea()

            if isUITestingAuth {
                AuthFlowView()
            } else if isUITestingLoggedIn {
                MainTabView(deepLinkBookingId: .constant(nil))
            } else if showSplash {
                SplashVideoView {
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
                .ignoresSafeArea()
                .task {
                    try? await Task.sleep(for: .seconds(8))
                    if showSplash {
                        withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
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
    }
}

#Preview {
    RootView()
}
