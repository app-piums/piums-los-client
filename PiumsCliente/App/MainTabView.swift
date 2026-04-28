// MainTabView.swift — 5 tabs (Home · Explore · My Space · Inbox · Perfil) + FAB
import SwiftUI

struct MainTabView: View {
    @Binding var deepLinkBookingId: String?
    @State private var selectedTab = 0
    @State private var bookingsPath = NavigationPath()
    @State private var chatStore = ChatRealtimeStore.shared
    @AppStorage("hasSeenHowItWorks") private var hasSeenHowItWorks = false
    @State private var showHowItWorks = false
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var tutorial = TutorialManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Inicio",     systemImage: "house.fill") }
                .tag(0)

            NavigationStack { SearchView() }
                .tabItem { Label("Explorar",  systemImage: "magnifyingglass") }
                .tag(1)

            NavigationStack(path: $bookingsPath) { MySpaceView() }
                .tabItem { Label("Mi Espacio", systemImage: "square.grid.2x2.fill") }
                .tag(2)

            NavigationStack { InboxView() }
                .tabItem { Label("Mensajes",    systemImage: "message.fill") }
                .badge(chatStore.unreadCount)
                .tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil",   systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Color.piumsOrange)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMySpace)) { _ in
            selectedTab = 2
        }
        .onChange(of: deepLinkBookingId) { _, bookingId in
            guard let bookingId else { return }
            selectedTab = 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bookingsPath.append(bookingId)
                deepLinkBookingId = nil
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            chatStore.setActive(newPhase == .active)
        }
        .task { chatStore.startIfNeeded() }
        .task {
            let skipTutorial = CommandLine.arguments.contains("UI_TESTING_SKIP_TUTORIAL")
            if !hasSeenHowItWorks && !skipTutorial {
                try? await Task.sleep(nanoseconds: 800_000_000)
                showHowItWorks = true
            }
        }
        .sheet(isPresented: $showHowItWorks) {
            HowItWorksView(
                onDismiss: {
                    hasSeenHowItWorks = true
                    showHowItWorks = false
                },
                onNavigate: { tab in
                    hasSeenHowItWorks = true
                    showHowItWorks = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedTab = tab
                    }
                }
            )
        }
        // ── Tour interactivo overlay ──
        .overlay {
            if tutorial.isActive {
                TourOverlayView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(100)
                    .ignoresSafeArea()
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tutorial.isActive)
        .onChange(of: tutorial.currentTabTarget) { _, newTab in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedTab = newTab }
        }
        .onChange(of: tutorial.isActive) { _, active in
            if active {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedTab = tutorial.currentTabTarget
                }
            }
        }
    }
}


#Preview {
    MainTabView(deepLinkBookingId: .constant(nil))
}
