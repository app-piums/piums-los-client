// MainTabView.swift — barra de tabs principal del cliente
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Inicio", systemImage: "house.fill") }

            NavigationStack { SearchView() }
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }

            NavigationStack { MyBookingsView() }
                .tabItem { Label("Reservas", systemImage: "calendar") }

            NavigationStack { NotificationsView() }
                .tabItem { Label("Alertas", systemImage: "bell.fill") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.fill") }
        }
        .tint(.piumsOrange)
    }
}

#Preview {
    MainTabView()
}
