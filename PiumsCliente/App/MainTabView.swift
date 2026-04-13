// MainTabView.swift — 5 tabs (Home · Explore · My Space · Inbox · Perfil) + FAB
import SwiftUI

struct MainTabView: View {
    @Binding var deepLinkBookingId: String?
    @State private var selectedTab = 0
    @State private var bookingsPath = NavigationPath()
    @State private var showFABMenu = false
    @State private var chatStore = ChatRealtimeStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ── Tab View ──────────────────────────────────
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

            // ── FAB ───────────────────────────────────────
            FABButton(isExpanded: $showFABMenu)
                .padding(.trailing, 20)
                .padding(.bottom, 80)   // encima del tab bar
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
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - FAB
// ══════════════════════════════════════════════════════════════

private struct FABButton: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.piumsOrange)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.piumsOrange.opacity(0.4), radius: 10, y: 4)
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
        }
    }
}

#Preview {
    MainTabView(deepLinkBookingId: .constant(nil))
}
