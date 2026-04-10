// RootView.swift — decide si mostrar onboarding, auth o la app principal
import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var deepLinkBookingId: String?

    var body: some View {
        Group {
            if !hasSeenOnboarding {
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
