// MainTabView.swift — 5 tabs (Home · Explore · My Space · Inbox · Perfil) + FAB
import SwiftUI

struct MainTabView: View {
    @Binding var deepLinkBookingId: String?
    @Binding var deepLinkDisputeId: String?
    @State private var selectedTab = 0
    @State private var bookingsPath = NavigationPath()
    @State private var chatStore = ChatRealtimeStore.shared
    @AppStorage("hasSeenHowItWorks") private var hasSeenHowItWorks = false
    @State private var showHowItWorks = false
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var tutorial = TutorialManager.shared

    var body: some View {
        tabsView
            .tint(Color.piumsOrange)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .applyDeepLinkHandlers(
                deepLinkBookingId: $deepLinkBookingId,
                deepLinkDisputeId: $deepLinkDisputeId,
                selectedTab: $selectedTab,
                bookingsPath: $bookingsPath
            )
            .applyTutorialHandlers(
                tutorial: tutorial,
                selectedTab: $selectedTab
            )
            .onChange(of: scenePhase) { _, newPhase in chatStore.setActive(newPhase == .active) }
            .task { chatStore.startIfNeeded() }
            .task { NotificationsStore.shared.startIfNeeded() }
            .task { AppDelegate.requestPushPermission() }
            .task { await launchHowItWorksIfNeeded() }
            .sheet(isPresented: $showHowItWorks) { howItWorksSheet }
            .overlay { tourOverlay }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tutorial.isActive)
    }

    // MARK: - Sub-views

    private var tabsView: some View {
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
                .tabItem { Label("Mensajes",   systemImage: "message.fill") }
                .badge(chatStore.unreadCount)
                .tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil",     systemImage: "person.fill") }
                .tag(4)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMySpace))      { _ in selectedTab = 2 }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCoupons))      { _ in selectedTab = 2 }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { _ in selectedTab = 3 }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToProfile))      { _ in selectedTab = 4 }
    }

    @ViewBuilder private var howItWorksSheet: some View {
        HowItWorksView(
            onDismiss: {
                hasSeenHowItWorks = true
                showHowItWorks = false
                TutorialManager.shared.startIfFirstTime()
            },
            onNavigate: { tab in
                hasSeenHowItWorks = true
                showHowItWorks = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { selectedTab = tab }
                TutorialManager.shared.startIfFirstTime()
            }
        )
    }

    @ViewBuilder private var tourOverlay: some View {
        if tutorial.isActive {
            TourOverlayView()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(100)
                .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    private func launchHowItWorksIfNeeded() async {
        let skipTutorial = CommandLine.arguments.contains("UI_TESTING_SKIP_TUTORIAL")
        guard !hasSeenHowItWorks && !skipTutorial else { return }
        try? await Task.sleep(nanoseconds: 800_000_000)
        showHowItWorks = true
    }
}

// MARK: - View modifier helpers to break up type-check complexity

private extension View {
    func applyDeepLinkHandlers(
        deepLinkBookingId: Binding<String?>,
        deepLinkDisputeId: Binding<String?>,
        selectedTab: Binding<Int>,
        bookingsPath: Binding<NavigationPath>
    ) -> some View {
        self
            .onChange(of: deepLinkBookingId.wrappedValue) { _, bookingId in
                guard let bookingId else { return }
                selectedTab.wrappedValue = 2
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bookingsPath.wrappedValue.append(bookingId)
                    deepLinkBookingId.wrappedValue = nil
                }
            }
            .onChange(of: deepLinkDisputeId.wrappedValue) { _, disputeId in
                guard disputeId != nil else { return }
                selectedTab.wrappedValue = 4
                deepLinkDisputeId.wrappedValue = nil
            }
    }

    func applyTutorialHandlers(
        tutorial: TutorialManager,
        selectedTab: Binding<Int>
    ) -> some View {
        self
            .onChange(of: tutorial.currentTabTarget) { _, newTab in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedTab.wrappedValue = newTab }
            }
            .onChange(of: tutorial.isActive) { _, active in
                guard active else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedTab.wrappedValue = tutorial.currentTabTarget
                }
            }
    }
}


#Preview {
    MainTabView(deepLinkBookingId: .constant(nil), deepLinkDisputeId: .constant(nil))
}
