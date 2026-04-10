// MainTabView.swift — 4 tabs (Home · Explore · Bookings · Events) + FAB
import SwiftUI

struct MainTabView: View {
    @Binding var deepLinkBookingId: String?
    @State private var selectedTab = 0
    @State private var bookingsPath = NavigationPath()
    @State private var showFABMenu = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ── Tab View ──────────────────────────────────
            TabView(selection: $selectedTab) {
                NavigationStack { HomeView() }
                    .tabItem { Label("Home",     systemImage: "house.fill") }
                    .tag(0)

                NavigationStack { SearchView() }
                    .tabItem { Label("Explore",  systemImage: "magnifyingglass") }
                    .tag(1)

                NavigationStack(path: $bookingsPath) { MyBookingsView() }
                    .tabItem { Label("Bookings", systemImage: "calendar") }
                    .tag(2)

                // Events — placeholder hasta implementar
                NavigationStack { EventsPlaceholderView() }
                    .tabItem { Label("Events",   systemImage: "ticket.fill") }
                    .tag(3)
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

// ══════════════════════════════════════════════════════════════
// MARK: - Events Placeholder
// ══════════════════════════════════════════════════════════════

private struct EventsPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "ticket.fill",
            title: "Events",
            description: "Próximamente podrás crear y gestionar eventos con múltiples artistas."
        )
        .navigationTitle("Events")
    }
}

#Preview {
    MainTabView(deepLinkBookingId: .constant(nil))
}
