// MainTabView.swift — barra de tabs principal del cliente
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

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

            NavigationStack { MyBookingsView() }
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
        .tint(.piumsOrange)
        // Tab bar siempre visible con material blur
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    MainTabView()
}
