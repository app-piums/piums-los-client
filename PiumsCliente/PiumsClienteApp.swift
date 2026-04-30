//
//  PiumsClienteApp.swift
//  PiumsCliente
//
//  Created by piums on 9/04/26.
//

import SwiftUI
import GoogleSignIn

// Detecta claves de configuración sin reemplazar antes de que el build llegue a QA/Prod.
private func validateBuildConfig() {
    let placeholders = ["REPLACE_ME", "YOUR_KEY", "INSERT_KEY"]
    let keys: [(name: String, value: String?)] = [
        ("STRIPE_PUBLISHABLE_KEY", Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String),
        ("API_BASE_URL",           Bundle.main.infoDictionary?["API_BASE_URL"] as? String),
    ]
    for key in keys {
        guard let value = key.value else {
            assertionFailure("⚠️ Build config: \(key.name) no está definida en el xcconfig")
            continue
        }
        let isPlaceholder = placeholders.contains { value.contains($0) }
        assert(!isPlaceholder, "⚠️ Build config: \(key.name) todavía contiene un placeholder ('\(value)'). Actualiza el xcconfig antes de distribuir.")
    }
}

@main
struct PiumsClienteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        validateBuildConfig()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(themeManager.colorScheme)
                .environmentObject(themeManager)
                .environment(\.locationStore, LocationStore.shared)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    themeManager.applyToWindows()
                    LocationStore.shared.requestIfNeeded()
                }
                .onChange(of: themeManager.storedScheme) { _, _ in
                    themeManager.applyToWindows()
                }
        }
    }
}
