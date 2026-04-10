// MainTabView.swift — barra de tabs principal del cliente
import SwiftUI

struct MainTabView: View {
    @Binding var deepLinkBookingId: String?
    @State private var selectedTab = 0
    @State private var bookingsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(0)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            NavigationStack { SearchView() }
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                .tag(1)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            NavigationStack(path: $bookingsPath) { MyBookingsView() }
                .tabItem { Label("Reservas", systemImage: "calendar") }
                .tag(2)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            NavigationStack { NotificationsView() }
                .tabItem { Label("Alertas", systemImage: "bell.fill") }
                .tag(3)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.fill") }
                .tag(4)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        }
        .tint(Color.piumsOrange)
        // Tab bar siempre visible con material blur
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: deepLinkBookingId) { _, bookingId in
            guard let bookingId else { return }
            selectedTab = 2   // ir a tab Reservas
            // Navegar al detalle cuando MyBookingsView ya está en pantalla
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bookingsPath.append(bookingId)
                deepLinkBookingId = nil
            }
        }
    }
}

#Preview {
    MainTabView(deepLinkBookingId: .constant(nil))
}
