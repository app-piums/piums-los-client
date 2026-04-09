// RootView.swift — decide si mostrar auth o la app principal
import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
    }
}

#Preview {
    RootView()
}
